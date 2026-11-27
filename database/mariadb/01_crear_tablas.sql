/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   01_crear_tablas.sql
   Equivalente de database/sql/01_crear_tablas.sql (SQL Server).
   Crea las 13 tablas y los datos iniciales (2 roles y 9 categorias).
   EJECUTAR UNA SOLA VEZ, sobre la base GravityFinance vacia.
   Los nombres de tablas y columnas son identicos a los de SQL Server.
   ===================================================================== */
SET NAMES utf8mb4;


/* ===== SEGURIDAD: usuarios y roles ===== */
CREATE TABLE Usuarios (
    id_usuario      INT NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(60)  NOT NULL,
    apellido        VARCHAR(60)  NULL,
    correo          VARCHAR(120) NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
    fecha_registro  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_Usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_Usuarios_correo UNIQUE (correo),
    CONSTRAINT CK_Usuarios_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Roles (
    id_rol      INT NOT NULL AUTO_INCREMENT,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion VARCHAR(150) NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (id_rol),
    CONSTRAINT UQ_Roles_nombre UNIQUE (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE UsuarioRol (
    id_usuario INT NOT NULL,
    id_rol     INT NOT NULL,
    CONSTRAINT PK_UsuarioRol PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT FK_UsuarioRol_Usuarios FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario),
    CONSTRAINT FK_UsuarioRol_Roles    FOREIGN KEY (id_rol)     REFERENCES Roles (id_rol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== CUENTAS Y CATEGORIAS ===== */
CREATE TABLE Cuentas (
    id_cuenta     INT NOT NULL AUTO_INCREMENT,
    id_usuario    INT NOT NULL,
    nombre_cuenta VARCHAR(60) NOT NULL,
    tipo_cuenta   VARCHAR(10) NOT NULL,
    moneda        CHAR(3)     NOT NULL DEFAULT 'CRC',
    saldo         DECIMAL(14,2) NOT NULL DEFAULT 0,
    estado        VARCHAR(10) NOT NULL DEFAULT 'ACTIVA',
    CONSTRAINT PK_Cuentas PRIMARY KEY (id_cuenta),
    CONSTRAINT FK_Cuentas_Usuarios FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario),
    CONSTRAINT UQ_Cuentas_usuario_nombre UNIQUE (id_usuario, nombre_cuenta),
    CONSTRAINT CK_Cuentas_tipo   CHECK (tipo_cuenta IN ('EFECTIVO','BANCO','TARJETA')),
    CONSTRAINT CK_Cuentas_moneda CHECK (moneda IN ('CRC','USD')),
    CONSTRAINT CK_Cuentas_estado CHECK (estado IN ('ACTIVA','CERRADA'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Categorias (
    id_categoria     INT NOT NULL AUTO_INCREMENT,
    nombre_categoria VARCHAR(50) NOT NULL,
    tipo_categoria   VARCHAR(7)  NOT NULL,
    CONSTRAINT PK_Categorias PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_Categorias_nombre UNIQUE (nombre_categoria),
    CONSTRAINT CK_Categorias_tipo CHECK (tipo_categoria IN ('INGRESO','GASTO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== MOVIMIENTOS (con especializacion en Ingresos y Gastos) ===== */
CREATE TABLE Movimientos (
    id_movimiento   INT NOT NULL AUTO_INCREMENT,
    id_cuenta       INT NOT NULL,
    id_categoria    INT NOT NULL,
    tipo_movimiento VARCHAR(7) NOT NULL,
    monto           DECIMAL(14,2) NOT NULL,
    fecha           DATE NOT NULL DEFAULT (CURRENT_DATE),
    descripcion     VARCHAR(150) NULL,
    estado          VARCHAR(8) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT PK_Movimientos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Movimientos_Cuentas    FOREIGN KEY (id_cuenta)    REFERENCES Cuentas (id_cuenta),
    CONSTRAINT FK_Movimientos_Categorias FOREIGN KEY (id_categoria) REFERENCES Categorias (id_categoria),
    CONSTRAINT CK_Movimientos_tipo   CHECK (tipo_movimiento IN ('INGRESO','GASTO')),
    CONSTRAINT CK_Movimientos_monto  CHECK (monto > 0),
    CONSTRAINT CK_Movimientos_estado CHECK (estado IN ('ACTIVO','ANULADO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Ingresos (
    id_movimiento INT NOT NULL,
    fuente        VARCHAR(80) NOT NULL,
    CONSTRAINT PK_Ingresos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Ingresos_Movimientos FOREIGN KEY (id_movimiento)
        REFERENCES Movimientos (id_movimiento) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Gastos (
    id_movimiento INT NOT NULL,
    comercio      VARCHAR(80) NOT NULL,
    metodo_pago   VARCHAR(13) NOT NULL,
    CONSTRAINT PK_Gastos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Gastos_Movimientos FOREIGN KEY (id_movimiento)
        REFERENCES Movimientos (id_movimiento) ON DELETE CASCADE,
    CONSTRAINT CK_Gastos_metodo CHECK (metodo_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== TRANSFERENCIAS ENTRE CUENTAS ===== */
CREATE TABLE Transferencias (
    id_transferencia  INT NOT NULL AUTO_INCREMENT,
    id_cuenta_origen  INT NOT NULL,
    id_cuenta_destino INT NOT NULL,
    monto             DECIMAL(14,2) NOT NULL,
    fecha             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descripcion       VARCHAR(150) NULL,
    CONSTRAINT PK_Transferencias PRIMARY KEY (id_transferencia),
    CONSTRAINT FK_Transf_Origen  FOREIGN KEY (id_cuenta_origen)  REFERENCES Cuentas (id_cuenta),
    CONSTRAINT FK_Transf_Destino FOREIGN KEY (id_cuenta_destino) REFERENCES Cuentas (id_cuenta),
    CONSTRAINT CK_Transf_monto     CHECK (monto > 0),
    CONSTRAINT CK_Transf_distintas CHECK (id_cuenta_origen <> id_cuenta_destino)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== PRESUPUESTOS ===== */
CREATE TABLE Presupuestos (
    id_presupuesto INT NOT NULL AUTO_INCREMENT,
    id_usuario     INT NOT NULL,
    id_categoria   INT NOT NULL,
    monto_limite   DECIMAL(14,2) NOT NULL,
    mes            TINYINT  UNSIGNED NOT NULL,
    anio           SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT PK_Presupuestos PRIMARY KEY (id_presupuesto),
    CONSTRAINT FK_Presupuestos_Usuarios   FOREIGN KEY (id_usuario)   REFERENCES Usuarios (id_usuario),
    CONSTRAINT FK_Presupuestos_Categorias FOREIGN KEY (id_categoria) REFERENCES Categorias (id_categoria),
    CONSTRAINT UQ_Presupuestos_periodo UNIQUE (id_usuario, id_categoria, mes, anio),
    CONSTRAINT CK_Presupuestos_monto CHECK (monto_limite > 0),
    CONSTRAINT CK_Presupuestos_mes   CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT CK_Presupuestos_anio  CHECK (anio BETWEEN 2000 AND 2100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== METAS DE AHORRO Y SUS APORTES ===== */
CREATE TABLE MetasAhorro (
    id_meta        INT NOT NULL AUTO_INCREMENT,
    id_usuario     INT NOT NULL,
    nombre_meta    VARCHAR(80) NOT NULL,
    monto_objetivo DECIMAL(14,2) NOT NULL,
    monto_actual   DECIMAL(14,2) NOT NULL DEFAULT 0,
    fecha_limite   DATE NULL,
    estado         VARCHAR(10) NOT NULL DEFAULT 'EN_CURSO',
    CONSTRAINT PK_MetasAhorro PRIMARY KEY (id_meta),
    CONSTRAINT FK_Metas_Usuarios FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario),
    CONSTRAINT CK_Metas_objetivo CHECK (monto_objetivo > 0),
    CONSTRAINT CK_Metas_actual   CHECK (monto_actual >= 0),
    CONSTRAINT CK_Metas_estado   CHECK (estado IN ('EN_CURSO','CUMPLIDA','CANCELADA'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE AportesMeta (
    id_aporte  INT NOT NULL AUTO_INCREMENT,
    id_meta    INT NOT NULL,
    id_cuenta  INT NOT NULL,
    monto      DECIMAL(14,2) NOT NULL,
    fecha      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_AportesMeta PRIMARY KEY (id_aporte),
    CONSTRAINT FK_Aportes_Metas   FOREIGN KEY (id_meta)   REFERENCES MetasAhorro (id_meta),
    CONSTRAINT FK_Aportes_Cuentas FOREIGN KEY (id_cuenta) REFERENCES Cuentas (id_cuenta),
    CONSTRAINT CK_Aportes_monto CHECK (monto > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== BITACORA (la llenan los triggers) ===== */
CREATE TABLE BitacoraMovimientos (
    id_bitacora    BIGINT NOT NULL AUTO_INCREMENT,
    id_movimiento  INT NOT NULL,
    operacion      VARCHAR(6) NOT NULL,
    monto_anterior DECIMAL(14,2) NULL,
    monto_nuevo    DECIMAL(14,2) NULL,
    usuario_bd     VARCHAR(128) NOT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_BitacoraMovimientos PRIMARY KEY (id_bitacora),
    CONSTRAINT CK_Bitacora_operacion CHECK (operacion IN ('INSERT','UPDATE','DELETE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/* ===== DATOS INICIALES ===== */
INSERT INTO Roles (nombre, descripcion) VALUES
    ('Administrador', 'Administra las categorías y ve toda la información'),
    ('Usuario',       'Maneja sus propias cuentas, movimientos, presupuestos y metas');

INSERT INTO Categorias (nombre_categoria, tipo_categoria) VALUES
    ('Salario',          'INGRESO'),
    ('Otros ingresos',   'INGRESO'),
    ('Alimentación',     'GASTO'),
    ('Transporte',       'GASTO'),
    ('Vivienda',         'GASTO'),
    ('Servicios',        'GASTO'),
    ('Salud',            'GASTO'),
    ('Educación',        'GASTO'),
    ('Entretenimiento',  'GASTO');
