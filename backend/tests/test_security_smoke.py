import importlib
import io
import os
import sys
import unittest
import warnings
from contextlib import contextmanager
from unittest import mock

from fastapi.testclient import TestClient
from PIL import Image

TEST_API_TOKEN = "unit-test-token-not-secret"


warnings.filterwarnings(
    "ignore",
    message=r"'asyncio\.iscoroutinefunction' is deprecated and slated for removal in Python 3\.16; use inspect\.iscoroutinefunction\(\) instead",
    category=DeprecationWarning,
)


@contextmanager
def app_env(**overrides):
    original = {key: os.environ.get(key) for key in overrides}
    try:
        for key, value in overrides.items():
            os.environ[key] = value
        yield
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def purge_app_modules() -> None:
    for name in list(sys.modules):
        if name == "app" or name.startswith("app."):
            del sys.modules[name]


def load_test_client(**env_overrides) -> TestClient:
    base_env = {
        "ENVIRONMENT": "development",
        "DEV_MOCK_IDENTIFY": "false",
        "API_TOKEN": TEST_API_TOKEN,
        "MARIADB_PASSWORD": "x",
        "ANTHROPIC_API_KEY": "key",
    }
    base_env.update(env_overrides)
    purge_app_modules()
    with app_env(**base_env):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            app = importlib.import_module("app.main").app
        return TestClient(app)


class SecuritySmokeTests(unittest.TestCase):
    def setUp(self):
        purge_app_modules()

    def _exhibit_payload(self, *, photos_base64=None):
        return {
            "name": "Commodore 64",
            "type": "Komputer",
            "vendor": "Commodore",
            "model": "C64",
            "serial_number": "ABC123",
            "part_number": "PN-1",
            "revision": "Assy 250466",
            "production_year": 1984,
            "status": "Niesprawdzony",
            "storage_place": "Regał A",
            "description": "Testowy wpis",
            "value": 1000,
            "has_original_packaging": False,
            "photos_base64": photos_base64 or [],
        }

    def _jpeg_bytes(self, size=(32, 32), color=(0, 255, 0)):
        jpeg = io.BytesIO()
        Image.new("RGB", size, color).save(jpeg, format="JPEG")
        return jpeg.getvalue()

    def test_missing_bearer_token_returns_401_with_challenge(self):
        client = load_test_client()

        response = client.get("/api/v1/dictionaries/types")

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "Missing Bearer token")
        self.assertEqual(response.headers.get("www-authenticate"), "Bearer")
        self.assertEqual(response.headers.get("x-content-type-options"), "nosniff")
        self.assertEqual(response.headers.get("x-frame-options"), "DENY")

    def test_security_headers_are_present_on_error_responses(self):
        client = load_test_client(DEV_MOCK_IDENTIFY="true")
        app = importlib.import_module("app.main").app
        app.state.limiter._storage.reset()

        response_404 = client.get("/definitely-missing")

        for _ in range(10):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )
            self.assertEqual(response.status_code, 200)

        response_429 = client.post(
            "/api/v1/identify",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
        )

        client_500 = load_test_client()
        identify_api = importlib.import_module("app.api.identify")
        with mock.patch.object(identify_api, "identify", side_effect=RuntimeError("config broke")):
            response_500 = client_500.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )

        self.assertEqual(response_404.status_code, 404)
        self.assertEqual(response_429.status_code, 429)
        self.assertEqual(response_500.status_code, 500)

        for response in (response_404, response_429, response_500):
            self.assertEqual(response.headers.get("x-content-type-options"), "nosniff")
            self.assertEqual(response.headers.get("x-frame-options"), "DENY")

    def test_production_disables_docs_and_health_is_minimal(self):
        client = load_test_client(
            ENVIRONMENT="production",
            DEV_MOCK_IDENTIFY="false",
        )

        health = client.get("/health")
        docs = client.get("/docs")
        redoc = client.get("/redoc")
        openapi = client.get("/openapi.json")

        self.assertEqual(health.status_code, 200)
        self.assertEqual(health.json(), {"status": "ok", "version": "0.0.6"})
        self.assertEqual(docs.status_code, 404)
        self.assertEqual(redoc.status_code, 404)
        self.assertEqual(openapi.status_code, 404)

    def test_production_blocks_dev_mock_on_startup(self):
        purge_app_modules()
        with app_env(
            ENVIRONMENT="production",
            DEV_MOCK_IDENTIFY="true",
            API_TOKEN=TEST_API_TOKEN,
            MARIADB_PASSWORD="x",
            ANTHROPIC_API_KEY="key",
        ):
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", DeprecationWarning)
                with self.assertRaises(RuntimeError):
                    importlib.import_module("app.main")

    def test_similar_unavailable_returns_503_without_internal_details(self):
        client = load_test_client()
        similarity = importlib.import_module("app.similarity")
        similarity._IMPORT_ERROR = "SECRET-DETAIL-SHOULD-NOT-LEAK"

        image = io.BytesIO()
        Image.new("RGB", (16, 16), (255, 0, 0)).save(image, format="JPEG")
        response = client.post(
            "/api/v1/similar",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            files={"image": ("probe.jpg", image.getvalue(), "image/jpeg")},
        )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {"detail": "Similarity search chwilowo niedostępny"},
        )
        self.assertNotIn("SECRET-DETAIL-SHOULD-NOT-LEAK", response.text)

    def test_image_validation_rejects_svg_and_accepts_jpeg(self):
        image_utils = importlib.import_module("app.image_utils")
        HTTPException = importlib.import_module("fastapi").HTTPException

        with self.assertRaises(HTTPException) as svg_error:
            image_utils.validate_image_bytes(b"<svg onload=alert(1)></svg>", "probe")
        self.assertEqual(svg_error.exception.status_code, 400)

        jpeg = io.BytesIO()
        Image.new("RGB", (32, 32), (0, 255, 0)).save(jpeg, format="JPEG")
        image_utils.validate_image_bytes(jpeg.getvalue(), "probe")

    def test_exhibits_rejects_invalid_base64_photo(self):
        client = load_test_client()

        response = client.post(
            "/api/v1/exhibits",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            json=self._exhibit_payload(photos_base64=["%%%not-base64%%%"]),
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["detail"], "Zdjęcie #0: niepoprawny base64")

    def test_exhibits_rejects_oversized_photo_after_base64_decode(self):
        client = load_test_client()
        exhibits = importlib.import_module("app.api.exhibits")

        with mock.patch.object(exhibits, "MAX_PHOTO_BYTES", 4):
            response = client.post(
                "/api/v1/exhibits",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                json=self._exhibit_payload(photos_base64=["QUJDREVG"]),  # "ABCDEF" => 6 bytes
            )

        self.assertEqual(response.status_code, 413)
        self.assertEqual(response.json()["detail"], "Zdjęcie #0 przekracza 0 MB")

    def test_exhibits_success_path_writes_exhibit_and_photo(self):
        client = load_test_client()
        exhibits = importlib.import_module("app.api.exhibits")

        class FakeCursor:
            def __init__(self):
                self.calls = []

            def execute(self, sql, params=None):
                self.calls.append((sql, params))

        fake_cursor = FakeCursor()

        @contextmanager
        def fake_db_cursor():
            yield fake_cursor

        lookup_ids = iter(["type-id", "vendor-id", "model-id", "status-id", "storage-id"])

        with (
            mock.patch.object(exhibits, "db_cursor", fake_db_cursor),
            mock.patch.object(exhibits, "lookup_or_insert", side_effect=lambda *args, **kwargs: next(lookup_ids)),
            mock.patch.object(exhibits, "validate_image_bytes"),
            mock.patch.object(exhibits, "preprocess_for_storage", return_value=b"processed-jpeg"),
            mock.patch.object(exhibits.uuid, "uuid4", side_effect=["exhibit-uuid", "photo-uuid-1"]),
        ):
            response = client.post(
                "/api/v1/exhibits",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                json=self._exhibit_payload(photos_base64=["QUJDRA=="]),  # "ABCD"
            )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            response.json(),
            {"id": "exhibit-uuid", "photos_count": 1},
        )
        self.assertEqual(len(fake_cursor.calls), 2)
        self.assertIn("INSERT INTO eksponaty", fake_cursor.calls[0][0])
        self.assertEqual(fake_cursor.calls[0][1][0], "exhibit-uuid")
        self.assertEqual(fake_cursor.calls[0][1][1], "Commodore 64")
        self.assertIn("INSERT INTO photos", fake_cursor.calls[1][0])
        self.assertEqual(fake_cursor.calls[1][1], ("photo-uuid-1", "exhibit-uuid", b"processed-jpeg"))

    def test_get_exhibit_returns_404_when_record_missing(self):
        client = load_test_client()
        exhibits = importlib.import_module("app.api.exhibits")

        class FakeCursor:
            def execute(self, sql, params=None):
                self.last_query = (sql, params)

            def fetchone(self):
                return None

        fake_cursor = FakeCursor()

        @contextmanager
        def fake_db_cursor():
            yield fake_cursor

        with mock.patch.object(exhibits, "db_cursor", fake_db_cursor):
            response = client.get(
                "/api/v1/exhibits/missing-id",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            )

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["detail"], "Nie znaleziono eksponatu")

    def test_get_exhibit_returns_detail_with_photo_preview(self):
        client = load_test_client()
        exhibits = importlib.import_module("app.api.exhibits")

        class FakeCursor:
            def __init__(self):
                self.execute_calls = 0

            def execute(self, sql, params=None):
                self.execute_calls += 1

            def fetchone(self):
                return {
                    "id": "exhibit-1",
                    "name": "Commodore 64",
                    "type": "Komputer",
                    "vendor": "Commodore",
                    "model": "C64",
                    "serial_number": "ABC123",
                    "part_number": "PN-1",
                    "revision": "Assy 250466",
                    "production_year": 1984,
                    "status": "Niesprawdzony",
                    "storage_place": "Regał A",
                    "description": "Testowy wpis",
                    "has_original_packaging": 1,
                }

            def fetchall(self):
                return [{"photo": b"raw-photo-1"}, {"photo": b"raw-photo-2"}]

        fake_cursor = FakeCursor()

        @contextmanager
        def fake_db_cursor():
            yield fake_cursor

        with (
            mock.patch.object(exhibits, "db_cursor", fake_db_cursor),
            mock.patch.object(exhibits, "make_detail_image", return_value=b"detail-jpeg"),
        ):
            response = client.get(
                "/api/v1/exhibits/exhibit-1",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "id": "exhibit-1",
                "name": "Commodore 64",
                "type": "Komputer",
                "vendor": "Commodore",
                "model": "C64",
                "serial_number": "ABC123",
                "part_number": "PN-1",
                "revision": "Assy 250466",
                "production_year": 1984,
                "status": "Niesprawdzony",
                "storage_place": "Regał A",
                "description": "Testowy wpis",
                "has_original_packaging": True,
                "photo_b64": "ZGV0YWlsLWpwZWc=",
                "photos_count": 2,
            },
        )

    def test_get_exhibit_keeps_response_when_preview_generation_fails(self):
        client = load_test_client()
        exhibits = importlib.import_module("app.api.exhibits")

        class FakeCursor:
            def execute(self, sql, params=None):
                self.last_query = (sql, params)

            def fetchone(self):
                return {
                    "id": "exhibit-2",
                    "name": "Atari 800XL",
                    "type": "Komputer",
                    "vendor": "Atari",
                    "model": "800XL",
                    "serial_number": None,
                    "part_number": None,
                    "revision": None,
                    "production_year": 1983,
                    "status": "Niesprawdzony",
                    "storage_place": "Regał B",
                    "description": "Drugi wpis",
                    "has_original_packaging": 0,
                }

            def fetchall(self):
                return [{"photo": b"broken-photo"}]

        fake_cursor = FakeCursor()

        @contextmanager
        def fake_db_cursor():
            yield fake_cursor

        with (
            mock.patch.object(exhibits, "db_cursor", fake_db_cursor),
            mock.patch.object(exhibits, "make_detail_image", side_effect=RuntimeError("decode failed")),
        ):
            response = client.get(
                "/api/v1/exhibits/exhibit-2",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["id"], "exhibit-2")
        self.assertIsNone(body["photo_b64"])
        self.assertEqual(body["photos_count"], 1)
        self.assertEqual(body["name"], "Atari 800XL")

    def test_default_rate_limit_returns_429_on_61st_request(self):
        client = load_test_client()
        app = importlib.import_module("app.main").app
        dictionaries = importlib.import_module("app.api.dictionaries")
        app.state.limiter._storage.reset()

        class FakeCursor:
            def execute(self, sql, params=None):
                self.last_query = (sql, params)

            def fetchall(self):
                return [{"id": "1", "name": "Komputer"}]

        @contextmanager
        def fake_db_cursor():
            yield FakeCursor()

        with mock.patch.object(dictionaries, "db_cursor", fake_db_cursor):
            for _ in range(60):
                response = client.get(
                    "/api/v1/dictionaries/types",
                    headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                )
                self.assertEqual(response.status_code, 200)

            response_61 = client.get(
                "/api/v1/dictionaries/types",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            )

        self.assertEqual(response_61.status_code, 429)

    def test_similar_custom_rate_limit_returns_429_on_31st_request(self):
        client = load_test_client()
        app = importlib.import_module("app.main").app
        similar = importlib.import_module("app.api.similar")
        app.state.limiter._storage.reset()

        image = io.BytesIO()
        Image.new("RGB", (16, 16), (255, 0, 0)).save(image, format="JPEG")
        file_payload = {"image": ("probe.jpg", image.getvalue(), "image/jpeg")}

        @contextmanager
        def fake_db_cursor():
            class FakeCursor:
                def execute(self, sql, params=None):
                    self.last_query = (sql, params)

                def fetchall(self):
                    return []

            yield FakeCursor()

        with (
            mock.patch.object(similar, "search_similar", return_value=[]),
            mock.patch.object(similar, "index_size", return_value=0),
            mock.patch.object(similar, "db_cursor", fake_db_cursor),
        ):
            for _ in range(30):
                response = client.post(
                    "/api/v1/similar",
                    headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                    files=file_payload,
                )
                self.assertEqual(response.status_code, 200)

            response_31 = client.post(
                "/api/v1/similar",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files=file_payload,
            )

        self.assertEqual(response_31.status_code, 429)

    def test_identify_rejects_more_than_five_images(self):
        client = load_test_client()
        image_bytes = self._jpeg_bytes()
        files = [
            ("images", (f"img{i}.jpg", image_bytes, "image/jpeg"))
            for i in range(6)
        ]

        response = client.post(
            "/api/v1/identify",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            files=files,
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["detail"], "Wymagane 1-5 zdjęć, otrzymano 6")

    def test_identify_rejects_oversized_image(self):
        client = load_test_client()
        identify_api = importlib.import_module("app.api.identify")

        with mock.patch.object(identify_api, "MAX_IMAGE_BYTES", 4):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", b"ABCDEF", "image/jpeg")},
            )

        self.assertEqual(response.status_code, 413)
        self.assertEqual(response.json()["detail"], "Zdjęcie #1 przekracza 0 MB")

    def test_identify_rejects_invalid_image_payload(self):
        client = load_test_client()

        response = client.post(
            "/api/v1/identify",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            files={"images": ("img.svg", b"<svg onload=alert(1)></svg>", "image/svg+xml")},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("zdjęcie #1: niepoprawny obraz", response.json()["detail"])

    def test_identify_dev_mock_returns_mock_payload_without_real_api(self):
        client = load_test_client(DEV_MOCK_IDENTIFY="true")
        identify_api = importlib.import_module("app.api.identify")

        with mock.patch.object(identify_api, "identify", side_effect=AssertionError("real API should not be called")):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["name"], "Klawiatura Amiga (mock)")
        self.assertEqual(body["type"], "Klawiatura")
        self.assertIn("MOCK", body["description"])

    def test_identify_rate_limit_returns_429_on_11th_request(self):
        client = load_test_client(DEV_MOCK_IDENTIFY="true")
        app = importlib.import_module("app.main").app
        app.state.limiter._storage.reset()

        for _ in range(10):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )
            self.assertEqual(response.status_code, 200)

        response_11 = client.post(
            "/api/v1/identify",
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
            files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
        )

        self.assertEqual(response_11.status_code, 429)

    def test_identify_runtime_error_returns_500_with_generic_message(self):
        client = load_test_client()
        identify_api = importlib.import_module("app.api.identify")

        with mock.patch.object(identify_api, "identify", side_effect=RuntimeError("missing ANTHROPIC_API_KEY")):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )

        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json()["detail"], "Błąd konfiguracji serwera")
        self.assertNotIn("ANTHROPIC_API_KEY", response.text)

    def test_identify_upstream_failure_returns_502_with_generic_message(self):
        client = load_test_client()
        identify_api = importlib.import_module("app.api.identify")

        with mock.patch.object(identify_api, "identify", side_effect=Exception("upstream exploded with payload details")):
            response = client.post(
                "/api/v1/identify",
                headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
                files={"images": ("img.jpg", self._jpeg_bytes(), "image/jpeg")},
            )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json()["detail"], "Claude API niedostępne")
        self.assertNotIn("payload details", response.text)


if __name__ == "__main__":
    unittest.main()
