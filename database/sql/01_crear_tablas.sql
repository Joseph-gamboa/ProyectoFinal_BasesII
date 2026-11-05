/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   01_crear_tablas.sql
   Crea las 13 tablas y los datos iniciales (2 roles y 9 categorias).
   EJECUTAR UNA SOLA VEZ, sobre la base GravityFinance vacia.
   Requiere: la base GravityFinance ya creada.
   ===================================================================== */
USE GravityFinance;
GO

/* ===== SEGURIDAD: usuarios y roles ===== */
CREATE TABLE dbo.Usuarios (
    id_usuario      INT IDENTITY(1,1) NOT NULL,
    nombre          NVARCHAR(60)  NOT NULL,
    apellido        NVARCHAR(60)  NULL,
    correo          NVARCHAR(120) NOT NULL,
    contrasena_hash NVARCHAR(255) NOT NULL,
    estado          VARCHAR(10)   NOT NULL CONSTRAINT DF_Usuarios_estado DEFAULT 'ACTIVO',
    fecha_registro  DATETIME2(0)  NOT NULL CONSTRAINT DF_Usuarios_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_Usuarios_correo UNIQUE (correo),
    CONSTRAINT CK_Usuarios_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE dbo.Roles (
    id_rol      INT IDENTITY(1,1) NOT NULL,
    nombre      VARCHAR(30)  NOT NULL,
    descripcion NVARCHAR(150) NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (id_rol),
    CONSTRAINT UQ_Roles_nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.UsuarioRol (
    id_usuario INT NOT NULL,
    id_rol     INT NOT NULL,
    CONSTRAINT PK_UsuarioRol PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT FK_UsuarioRol_Usuarios FOREIGN KEY (id_usuario) REFERENCES dbo.Usuarios (id_usuario),
    CONSTRAINT FK_UsuarioRol_Roles    FOREIGN KEY (id_rol)     REFERENCES dbo.Roles (id_rol)
);
GO

/* ===== CUENTAS Y CATEGORIAS ===== */
CREATE TABLE dbo.Cuentas (
    id_cuenta     INT IDENTITY(1,1) NOT NULL,
    id_usuario    INT NOT NULL,
    nombre_cuenta NVARCHAR(60) NOT NULL,
    tipo_cuenta   VARCHAR(10)  NOT NULL,
    moneda        CHAR(3)      NOT NULL CONSTRAINT DF_Cuentas_moneda DEFAULT 'CRC',
    saldo         DECIMAL(14,2) NOT NULL CONSTRAINT DF_Cuentas_saldo DEFAULT 0,
    estado        VARCHAR(10)  NOT NULL CONSTRAINT DF_Cuentas_estado DEFAULT 'ACTIVA',
    CONSTRAINT PK_Cuentas PRIMARY KEY (id_cuenta),
    CONSTRAINT FK_Cuentas_Usuarios FOREIGN KEY (id_usuario) REFERENCES dbo.Usuarios (id_usuario),
    CONSTRAINT UQ_Cuentas_usuario_nombre UNIQUE (id_usuario, nombre_cuenta),
    CONSTRAINT CK_Cuentas_tipo   CHECK (tipo_cuenta IN ('EFECTIVO','BANCO','TARJETA')),
    CONSTRAINT CK_Cuentas_moneda CHECK (moneda IN ('CRC','USD')),
    CONSTRAINT CK_Cuentas_estado CHECK (estado IN ('ACTIVA','CERRADA'))
);
GO

CREATE TABLE dbo.Categorias (
    id_categoria     INT IDENTITY(1,1) NOT NULL,
    nombre_categoria NVARCHAR(50) NOT NULL,
    tipo_categoria   VARCHAR(7)   NOT NULL,
    CONSTRAINT PK_Categorias PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_Categorias_nombre UNIQUE (nombre_categoria),
    CONSTRAINT CK_Categorias_tipo CHECK (tipo_categoria IN ('INGRESO','GASTO'))
);
GO

/* ===== MOVIMIENTOS (con especializacion en Ingresos y Gastos) ===== */
CREATE TABLE dbo.Movimientos (
    id_movimiento   INT IDENTITY(1,1) NOT NULL,
    id_cuenta       INT NOT NULL,
    id_categoria    INT NOT NULL,
    tipo_movimiento VARCHAR(7) NOT NULL,
    monto           DECIMAL(14,2) NOT NULL,
    fecha           DATE NOT NULL CONSTRAINT DF_Movimientos_fecha DEFAULT CAST(SYSDATETIME() AS DATE),
    descripcion     NVARCHAR(150) NULL,
    estado          VARCHAR(8) NOT NULL CONSTRAINT DF_Movimientos_estado DEFAULT 'ACTIVO',
    CONSTRAINT PK_Movimientos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Movimientos_Cuentas    FOREIGN KEY (id_cuenta)    REFERENCES dbo.Cuentas (id_cuenta),
    CONSTRAINT FK_Movimientos_Categorias FOREIGN KEY (id_categoria) REFERENCES dbo.Categorias (id_categoria),
    CONSTRAINT CK_Movimientos_tipo   CHECK (tipo_movimiento IN ('INGRESO','GASTO')),
    CONSTRAINT CK_Movimientos_monto  CHECK (monto > 0),
    CONSTRAINT CK_Movimientos_estado CHECK (estado IN ('ACTIVO','ANULADO'))
);
GO

CREATE TABLE dbo.Ingresos (
    id_movimiento INT NOT NULL,
    fuente        NVARCHAR(80) NOT NULL,
    CONSTRAINT PK_Ingresos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Ingresos_Movimientos FOREIGN KEY (id_movimiento)
        REFERENCES dbo.Movimientos (id_movimiento) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.Gastos (
    id_movimiento INT NOT NULL,
    comercio      NVARCHAR(80) NOT NULL,
    metodo_pago   VARCHAR(13)  NOT NULL,
    CONSTRAINT PK_Gastos PRIMARY KEY (id_movimiento),
    CONSTRAINT FK_Gastos_Movimientos FOREIGN KEY (id_movimiento)
        REFERENCES dbo.Movimientos (id_movimiento) ON DELETE CASCADE,
    CONSTRAINT CK_Gastos_metodo CHECK (metodo_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA'))
);
GO

/* ===== TRANSFERENCIAS ENTRE CUENTAS ===== */
CREATE TABLE dbo.Transferencias (
    id_transferencia  INT IDENTITY(1,1) NOT NULL,
    id_cuenta_origen  INT NOT NULL,
    id_cuenta_destino INT NOT NULL,
    monto             DECIMAL(14,2) NOT NULL,
    fecha             DATETIME2(0) NOT NULL CONSTRAINT DF_Transferencias_fecha DEFAULT SYSDATETIME(),
    descripcion       NVARCHAR(150) NULL,
    CONSTRAINT PK_Transferencias PRIMARY KEY (id_transferencia),
    CONSTRAINT FK_Transf_Origen  FOREIGN KEY (id_cuenta_origen)  REFERENCES dbo.Cuentas (id_cuenta),
    CONSTRAINT FK_Transf_Destino FOREIGN KEY (id_cuenta_destino) REFERENCES dbo.Cuentas (id_cuenta),
    CONSTRAINT CK_Transf_monto    CHECK (monto > 0),
    CONSTRAINT CK_Transf_distintas CHECK (id_cuenta_origen <> id_cuenta_destino)
);
GO

/* ===== PRESUPUESTOS ===== */
CREATE TABLE dbo.Presupuestos (
    id_presupuesto INT IDENTITY(1,1) NOT NULL,
    id_usuario     INT NOT NULL,
    id_categoria   INT NOT NULL,
    monto_limite   DECIMAL(14,2) NOT NULL,
    mes            TINYINT  NOT NULL,
    anio           SMALLINT NOT NULL,
    CONSTRAINT PK_Presupuestos PRIMARY KEY (id_presupuesto),
    CONSTRAINT FK_Presupuestos_Usuarios    FOREIGN KEY (id_usuario)   REFERENCES dbo.Usuarios (id_usuario),
    CONSTRAINT FK_Presupuestos_Categorias  FOREIGN KEY (id_categoria) REFERENCES dbo.Categorias (id_categoria),
    CONSTRAINT UQ_Presupuestos_periodo UNIQUE (id_usuario, id_categoria, mes, anio),
    CONSTRAINT CK_Presupuestos_monto CHECK (monto_limite > 0),
    CONSTRAINT CK_Presupuestos_mes   CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT CK_Presupuestos_anio  CHECK (anio BETWEEN 2000 AND 2100)
);
GO

/* ===== METAS DE AHORRO Y SUS APORTES ===== */
CREATE TABLE dbo.MetasAhorro (
    id_meta        INT IDENTITY(1,1) NOT NULL,
    id_usuario     INT NOT NULL,
    nombre_meta    NVARCHAR(80) NOT NULL,
    monto_objetivo DECIMAL(14,2) NOT NULL,
    monto_actual   DECIMAL(14,2) NOT NULL CONSTRAINT DF_Metas_actual DEFAULT 0,
    fecha_limite   DATE NULL,
    estado         VARCHAR(10) NOT NULL CONSTRAINT DF_Metas_estado DEFAULT 'EN_CURSO',
    CONSTRAINT PK_MetasAhorro PRIMARY KEY (id_meta),
    CONSTRAINT FK_Metas_Usuarios FOREIGN KEY (id_usuario) REFERENCES dbo.Usuarios (id_usuario),
    CONSTRAINT CK_Metas_objetivo CHECK (monto_objetivo > 0),
    CONSTRAINT CK_Metas_actual   CHECK (monto_actual >= 0),
    CONSTRAINT CK_Metas_estado   CHECK (estado IN ('EN_CURSO','CUMPLIDA','CANCELADA'))
);
GO

CREATE TABLE dbo.AportesMeta (
    id_aporte  INT IDENTITY(1,1) NOT NULL,
    id_meta    INT NOT NULL,
    id_cuenta  INT NOT NULL,
    monto      DECIMAL(14,2) NOT NULL,
    fecha      DATETIME2(0) NOT NULL CONSTRAINT DF_Aportes_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_AportesMeta PRIMARY KEY (id_aporte),
    CONSTRAINT FK_Aportes_Metas   FOREIGN KEY (id_meta)   REFERENCES dbo.MetasAhorro (id_meta),
    CONSTRAINT FK_Aportes_Cuentas FOREIGN KEY (id_cuenta) REFERENCES dbo.Cuentas (id_cuenta),
    CONSTRAINT CK_Aportes_monto CHECK (monto > 0)
);
GO

/* ===== BITACORA (la llenan los triggers) ===== */
CREATE TABLE dbo.BitacoraMovimientos (
    id_bitacora    BIGINT IDENTITY(1,1) NOT NULL,
    id_movimiento  INT NOT NULL,
    operacion      VARCHAR(6) NOT NULL,
    monto_anterior DECIMAL(14,2) NULL,
    monto_nuevo    DECIMAL(14,2) NULL,
    usuario_bd     NVARCHAR(128) NOT NULL CONSTRAINT DF_Bitacora_usuario DEFAULT SUSER_SNAME(),
    fecha          DATETIME2(0) NOT NULL CONSTRAINT DF_Bitacora_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT PK_BitacoraMovimientos PRIMARY KEY (id_bitacora),
    CONSTRAINT CK_Bitacora_operacion CHECK (operacion IN ('INSERT','UPDATE','DELETE'))
);
GO

/* ===== DATOS INICIALES ===== */
INSERT INTO dbo.Roles (nombre, descripcion) VALUES
    ('Administrador', N'Administra las categorías y ve toda la información'),
    ('Usuario',       N'Maneja sus propias cuentas, movimientos, presupuestos y metas');
GO

INSERT INTO dbo.Categorias (nombre_categoria, tipo_categoria) VALUES
    (N'Salario',          'INGRESO'),
    (N'Otros ingresos',   'INGRESO'),
    (N'Alimentación',     'GASTO'),
    (N'Transporte',       'GASTO'),
    (N'Vivienda',         'GASTO'),
    (N'Servicios',        'GASTO'),
    (N'Salud',            'GASTO'),
    (N'Educación',        'GASTO'),
    (N'Entretenimiento',  'GASTO');
GO
