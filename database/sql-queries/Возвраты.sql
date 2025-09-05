-- =============================================
-- База данных: Возвраты с маркетплейсов
-- Автор: Роман Сошкин
-- Дата создания: 2024
-- =============================================

-- Таблица возвратов
CREATE TABLE return_orders (
    return_id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients(client_id),
    order_id INTEGER NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    offer_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    barcode VARCHAR(255) NOT NULL,
    status_id INTEGER NOT NULL REFERENCES return_statuses(status_id),
    reason TEXT NULL,
    created_at TIMESTAMP NOT NULL,
    ready_date TIMESTAMP NOT NULL,
    pickup_date TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(client_id, order_id, return_id)
);

--COMMENT ON TABLE return_orders IS 'Таблица для хранения информации о возвратах';
--COMMENT ON COLUMN return_orders.client_id IS 'Уникальный идентификатор клиента для каждого МП';
--COMMENT ON COLUMN return_orders.order_id IS 'Уникальный идентификатор заказа в системе';
--COMMENT ON COLUMN return_orders.order_number IS 'Номер заказа и номер пакета в маркетплейсе';
--COMMENT ON COLUMN return_orders.offer_id IS 'Артикул товара в системе';
--COMMENT ON COLUMN return_orders.quantity IS 'Количество возвращаемого товара';
--COMMENT ON COLUMN return_orders.barcode IS 'Штрих-код возвратного отправления';
--COMMENT ON COLUMN return_orders.status_id IS 'Статус возвратного заказа';
--COMMENT ON COLUMN return_orders.reason IS 'Текстовое описание причины возврата';
--COMMENT ON COLUMN return_orders.created_at IS 'Дата и время возврата клиентом';
--COMMENT ON COLUMN return_orders.ready_date IS 'Дата готовности возврата маркетплейсом';
--COMMENT ON COLUMN return_orders.pickup_date IS 'Дата получения возврата продавцом';

-- Таблица статусов возвратов
CREATE TABLE return_statuses (
    status_id SERIAL PRIMARY KEY,
    marketplace_name VARCHAR(20) NOT NULL CHECK (marketplace_name IN ('Ozon', 'Yandex', 'Wildberries')),
    status_code VARCHAR(10) NOT NULL,
    status_name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(marketplace_name, status_code)
);

--COMMENT ON TABLE return_statuses IS 'Справочник статусов возвратов для маркетплейсов';
--COMMENT ON COLUMN return_statuses.is_internal IS 'Флаг внутренних служебных статусов системы';

-- Таблица клиентов (пример)
CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    marketplace VARCHAR(20) NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
/*
-- Индексы для оптимизации
CREATE INDEX idx_return_orders_client ON return_orders(client_id);
CREATE INDEX idx_return_orders_status ON return_orders(status_id);
CREATE INDEX idx_return_orders_dates ON return_orders(created_at, ready_date, pickup_date);
CREATE INDEX idx_return_orders_barcode ON return_orders(barcode);
CREATE INDEX idx_return_statuses_marketplace ON return_statuses(marketplace_name);

-- Представление для удобства работы со статусами
CREATE OR REPLACE VIEW return_statuses_view AS
SELECT 
    rs.status_id,
    rs.marketplace_name,
    rs.status_code,
    rs.status_name,
    rs.description,
    rs.is_internal,
    CASE 
        WHEN rs.is_internal THEN 'Внутренний статус системы'
        ELSE 'Статус маркетплейса'
    END as status_type
FROM return_statuses rs
ORDER BY rs.marketplace_name, rs.status_code;
*/