-- =============================================
-- База данных: Интеграция с маркетплейсами
-- Автор: Роман Сошкин
-- Дата создания: 2024
-- =============================================

-- Создание базы данных
CREATE DATABASE marketplace_integration;
\c marketplace_integration;


-- Таблица продавцов
CREATE TABLE sellers (
    client_id SERIAL PRIMARY KEY,
    marketplace_name VARCHAR(50) NOT NULL,
    scheme VARCHAR(20) NOT NULL CHECK (scheme IN ('FBS', 'FBO', 'RealFBS')),
    description TEXT NULL,
    api_key VARCHAR(255) NULL,
    total_limit INTEGER NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица статусов
CREATE TABLE status_classifier (
    status_id SERIAL PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NULL
);

-- Таблица категорий
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    external_id INTEGER NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица брендов
CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица кодов ошибок
CREATE TABLE error_codes (
    error_id SERIAL PRIMARY KEY,
    error_code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    module VARCHAR(50) NOT NULL CHECK (module IN ('product', 'order', 'price', 'sync', 'api')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'ERROR')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица товаров
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES sellers(client_id) ON DELETE CASCADE,
    sku INTEGER NOT NULL,
    article VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    last_sync_date DATE NOT NULL,
    description TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE CASCADE,
    brand_id INTEGER REFERENCES brands(brand_id) ON DELETE CASCADE,
    status_id SMALLINT REFERENCES status_classifier(status_id) ON DELETE CASCADE,
    external_id INTEGER NULL,
    error_id INTEGER REFERENCES error_codes(error_id) ON DELETE SET NULL,
    marking_required BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица цен
CREATE TABLE prices (
    price_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id) ON DELETE CASCADE,
    base_price DECIMAL(10,2) NOT NULL,
    marketplace_price DECIMAL(10,2) NULL,
    currency VARCHAR(3) DEFAULT 'RUB',
    start_date DATE NOT NULL,
    end_date DATE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (base_price >= 0),
    CHECK (marketplace_price >= 0 OR marketplace_price IS NULL)
);

-- Таблица изображений
CREATE TABLE product_images (
    image_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица логов ошибок
CREATE TABLE error_logs (
    log_id SERIAL PRIMARY KEY,
    error_id INTEGER REFERENCES error_codes(error_id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL CHECK (entity_type IN ('product', 'order', 'price', 'sync')),
    entity_id INTEGER NOT NULL,
    details JSONB NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание индексов
CREATE INDEX idx_products_client_id ON products(client_id);
CREATE INDEX idx_products_status_id ON products(status_id);
CREATE INDEX idx_products_error_id ON products(error_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_prices_product_id ON prices(product_id);
CREATE INDEX idx_prices_dates ON prices(start_date, end_date);
CREATE INDEX idx_product_images_product_id ON product_images(product_id);
CREATE INDEX idx_error_logs_error_id ON error_logs(error_id);
CREATE INDEX idx_error_logs_entity ON error_logs(entity_type, entity_id);
CREATE INDEX idx_error_logs_resolved ON error_logs(resolved);

-- Уникальные ограничения
ALTER TABLE products ADD CONSTRAINT unique_client_sku UNIQUE (client_id, sku);
ALTER TABLE prices ADD CONSTRAINT unique_product_active_price 
EXCLUDE USING gist (product_id WITH =, daterange(start_date, end_date, '[]') WITH &&)
WHERE (end_date IS NULL OR end_date > CURRENT_DATE);

-- Представления для отчетности
CREATE OR REPLACE VIEW product_overview AS
SELECT 
    p.product_id,
    p.name as product_name,
    p.quantity,
    p.last_sync_date,
    c.category_name,
    b.brand_name,
    s.status_name,
    ec.error_code,
    ec.severity as error_severity,
    pr.base_price,
    pr.marketplace_price
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN brands b ON p.brand_id = b.brand_id
JOIN status_classifier s ON p.status_id = s.status_id
LEFT JOIN error_codes ec ON p.error_id = ec.error_id
LEFT JOIN prices pr ON p.product_id = pr.product_id 
    AND (pr.end_date IS NULL OR pr.end_date > CURRENT_DATE);

CREATE OR REPLACE VIEW error_report AS
SELECT 
    el.log_id,
    ec.error_code,
    ec.description as error_description,
    ec.severity,
    el.entity_type,
    el.entity_id,
    el.details,
    el.resolved,
    el.created_at,
    el.resolved_at
FROM error_logs el
JOIN error_codes ec ON el.error_id = ec.error_id;

-- Вставка тестовых данных
INSERT INTO status_classifier (status_name, description) VALUES
('active', 'Товар активен и готов к продаже'),
('inactive', 'Товар временно не доступен'),
('moderation', 'На модерации маркетплейса'),
('archived', 'Товар в архиве');

INSERT INTO categories (category_name, external_id) VALUES
('Ювелирные изделия', 17027900),
('Аксессуары', 17027904),
('Бижутерия', 17027901);

INSERT INTO brands (brand_name) VALUES
('Sunlight'),
('Pandora'),
('Sokolov');

INSERT INTO error_codes (error_code, description, module, severity) VALUES
('PRODUCT_SYNC_ERROR', 'Ошибка синхронизации товара', 'product', 'ERROR'),
('PRICE_UPDATE_FAILED', 'Не удалось обновить цену', 'price', 'WARNING'),
('API_CONNECTION_ERROR', 'Ошибка соединения с API', 'api', 'ERROR'),
('STOCK_VALIDATION_WARN', 'Предупреждение валидации остатков', 'sync', 'WARNING'),
('IMAGE_UPLOAD_FAILED', 'Ошибка загрузки изображения', 'product', 'ERROR');

INSERT INTO sellers (marketplace_name, scheme, description, total_limit) VALUES
('Ozon', 'FBS', 'Основной продавец на Ozon', 1000),
('Wildberries', 'FBO', 'Продавец на Wildberries', 500),
('Yandex Market', 'FBS', 'Продавец на Яндекс.Маркете', 300);
