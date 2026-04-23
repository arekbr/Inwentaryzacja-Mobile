-- Minimalny schemat dla symulacji. Prawdziwa baza zbiory ma więcej, ale do testów
-- bezp. wystarczą tabele słownikowe + eksponaty + photos.

CREATE TABLE IF NOT EXISTS types (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS vendors (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS models (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    vendor_id CHAR(36),
    INDEX (vendor_id)
);
CREATE TABLE IF NOT EXISTS statuses (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS storage_places (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS eksponaty (
    id CHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type_id CHAR(36),
    vendor_id CHAR(36),
    model_id CHAR(36),
    serial_number VARCHAR(255),
    part_number VARCHAR(255),
    revision VARCHAR(255),
    production_year INT,
    status_id CHAR(36),
    storage_place_id CHAR(36),
    description TEXT,
    value INT,
    has_original_packaging TINYINT(1) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS photos (
    id CHAR(36) NOT NULL PRIMARY KEY,
    eksponat_id CHAR(36) NOT NULL,
    filename VARCHAR(255),
    photo LONGBLOB,
    INDEX (eksponat_id)
);

-- Zapewnij że user inwentaryzacja ma grant na tę bazę (docker entrypoint tworzy user, ale bez USAGE może mieć ograniczenia)
GRANT ALL PRIVILEGES ON zbiory.* TO 'inwentaryzacja'@'%';
FLUSH PRIVILEGES;
