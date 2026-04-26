#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include <chrono>

class AppSettings;
class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

/**
 * HTTP client do FastAPI backendu (identify/similar/exhibits/dictionaries).
 * Zarejestrowany jako context property `apiClient` w QML.
 *
 * Wszystkie metody async, wyniki przez sygnały.
 */
class ApiClient : public QObject
{
    Q_OBJECT
public:
    explicit ApiClient(AppSettings *settings, QObject *parent = nullptr);

    /// Health probe — GET /health. Sprawdza czy API odpowiada.
    Q_INVOKABLE void checkHealth();

    /// POST /api/v1/identify — multipart z JPG. Wynik → identifyResult(artefakt).
    Q_INVOKABLE void identify(const QString &photoPath);

    /// POST /api/v1/exhibits — JSON z polami Artefakt + base64 zdjęcia.
    /// @param payload mapa pól (name, type, vendor, model, ...)
    /// @param photoPath ścieżka do JPG (odczytany i zakodowany do base64)
    Q_INVOKABLE void saveExhibit(const QVariantMap &payload, const QString &photoPath);

    /// POST /api/v1/similar?top_k=N — multipart z JPG. Wynik → similarResult(list).
    Q_INVOKABLE void findSimilar(const QString &photoPath, int topK = 5);

    /// GET /api/v1/exhibits/{id} — pełny eksponat + pierwsze zdjęcie 800px base64.
    Q_INVOKABLE void getExhibit(const QString &exhibitId);

    /// GET /api/v1/exhibits?page=N&per_page=M — paginowana lista alfabetycznie.
    Q_INVOKABLE void listExhibits(int page = 1, int perPage = 50);

signals:
    /// @param info map: {version, database, exhibits_count, clip_index_size, mock_identify, status}
    void healthOk(const QVariantMap &info);
    void healthError(const QString &message);

    void identifyResult(const QVariantMap &artefakt);
    void identifyError(const QString &message);

    void exhibitSaved(const QString &id, int photosCount);
    void exhibitError(const QString &message);

    /// @param results lista map: {exhibit_id, name, vendor, model, distance, thumbnail_b64}
    /// @param indexSize liczba wszystkich eksponatów w LanceDB (informacyjnie)
    void similarResult(const QVariantList &results, int indexSize);
    void similarError(const QString &message);

    void exhibitDetail(const QVariantMap &detail);
    /// Q-05: drugi arg `exhibitId` żeby strona mogła filtrować — bez tego
    /// error z requestu A surfacuje na stronie B (cross-page leak).
    void exhibitDetailError(const QString &message, const QString &exhibitId);

    /// @param page page number (1-based) — przydatne przy infinite scrollu
    /// @param info {results, total, page, per_page, has_more}
    void exhibitListResult(const QVariantMap &info);
    void exhibitListError(const QString &message);

    /// C-D09 wariant A: emitted gdy QUALSIWIEK request dostal 401.
    /// Token API jest sessional na Androidzie (nie persystuje przez kill — security
    /// tier-1.5 decision), wiec po restart user musi go wpisac ponownie.
    /// Glowny QML page lapie ten sygnal i kieruje usera do Ustawien.
    void tokenRequired();

private:
    /// C-D10: zwija boilerplate auth+timeout+url z 5 endpointów do jednego miejsca.
    /// L-02: timeout jako std::chrono — type-safe, callsite czyta `45s` zamiast `45000`.
    /// C-D12: header `Bearer <token>` budowany 1× tutaj, nie 5× per endpoint.
    /// @param withAuth false dla /health (publiczny endpoint pre-token).
    QNetworkRequest prepareRequest(const QString &path,
                                   std::chrono::milliseconds timeout,
                                   bool withAuth = true) const;

    /// C-D03: onError jako parametr — wcześniej helper hardcodował emit identifyError
    /// dla wszystkich callerów, więc gdy ktoś dodał drugi endpoint to błąd otwarcia
    /// pliku trafiał w pageA gdy user był na pageB. Każdy caller daje swój sygnał.
    void sendMultipartPost(const QString &endpoint,
                           const QString &photoPath,
                           std::function<void(QNetworkReply *)> onFinish,
                           std::function<void(const QString &)> onError,
                           std::chrono::milliseconds timeout = std::chrono::seconds(30));

    /// Mapuje QNetworkReply::NetworkError + response body na ludzki polski komunikat.
    /// Surowe "Error transferring ... - server replied: ..." jest nieczytelne dla usera.
    /// C-D09: non-static (z static stale by emitowac tokenRequired) — potrzebny `this`.
    QString formatNetworkError(QNetworkReply *reply);

    /// C-D07: walidacja `photoPath` przed otwarciem QFile. Defense-in-depth:
    /// - canonicalFilePath (rezolwuje `..`, symlinki)
    /// - musi istnieć i być readable
    /// - rozszerzenie .jpg/.jpeg/.png/.heic
    /// - magic bytes JPEG (FFD8FF) lub PNG (89 50 4E 47)
    /// Zwraca pustą string jeśli OK, error message jeśli nie.
    static QString validatePhotoPath(const QString &photoPath);

    AppSettings *m_settings;
    QNetworkAccessManager *m_nam;
};
