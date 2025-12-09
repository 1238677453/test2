{
  Главный модуль для работы с Python C API в Free Pascal.

  Этот модуль содержит основные определения, типы и функции, необходимые
  для взаимодействия с интерпретатором CPython. Он обеспечивает
  кроссплатформенную совместимость для Windows, Linux и macOS.

  Целевая версия Python: 3.14

  Поддерживаемые режимы компиляции:
  - `PY_3.13`: Обеспечивает частичную совместимость с Python 3.13.
  - `Py_GIL_DISABLED`: Поддержка сборок Python без Global Interpreter Lock (GIL).
  - `PY_LIMITED_API`: Использование ограниченного стабильного ABI.
  - `Py_PORTABLE`: Для встраиваемых и портативных версий Python.

  Устаревший и нефункциональный API версии 3.14 исключён.
}
{$mode fpc}
{$I config.inc}// ключи компиляции
unit python;

interface

uses
  ctypes;

const
  {
    Версия C API, используемая при компиляции модуля.
    Это значение проверяется интерпретатором при загрузке, чтобы
    обеспечить совместимость.
  }
  PYTHON_API_VERSION = 1013;

  {
    Идентификаторы поддерживаемых библиотек для динамической загрузки.
    Массив содержит имена файлов библиотек Python для разных версий,
    что позволяет модулю работать с несколькими версиями Python.
  }
  {$IFDEF MSWINDOWS}
  PythonFullNameAr: array [0..1] of pansichar = ('python313.dll', 'python314.dll');
  {$ELSE}
  {$IFDEF DARWIN}
  PythonFullNameAr: array [0..1] of pansichar = ('libpython313.dylib', 'libpython314.dylib');
  {$ELSE}
  {$IFDEF LINUX}
  PythonFullNameAr: array [0..1] of pansichar = ('libpython313.so', 'libpython314.so');
  {$ELSE}
  PythonFullNameAr: array [0..1] of pansichar = ('libpython313.so', 'libpython314.so');
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  // ---------------------- C Standard Types -----------------------------
type
  { 8-битное беззнаковое целое (эквивалент `uint8_t` в C). }
  uint8_t    = byte;
  { Указатель на 8-битное беззнаковое целое. }
  puint8_t   = ^uint8_t;
  { 16-битное беззнаковое целое (эквивалент `uint16_t` в C). }
  uint16_t   = word;
  { Указатель на 16-битное беззнаковое целое. }
  puint16_t  = ^uint16_t;
  { 32-битное беззнаковое целое (эквивалент `uint32_t` в C). }
  uint32_t   = cardinal;
  { Указатель на 32-битное беззнаковое целое. }
  puint32_t  = ^uint32_t;
  { 64-битное беззнаковое целое (эквивалент `uint64_t` в C). }
  uint64_t   = qword;
  { Указатель на 64-битное беззнаковое целое. }
  puint64_t  = ^uint64_t;
  { Целочисленный тип, достаточный для хранения указателя (эквивалент `uintptr_t` в C). }
  uintptr_t  = nativeuint;
  { Указатель на целочисленный тип для хранения указателя. }
  puintptr_t = ^uintptr_t;

  // ------------------ CPython Core Types ---------------------------
  { Тип для хранения размеров или количества элементов (эквивалент `ssize_t` в C). }
  Py_ssize_t  = nativeint;
  { Указатель на Py_ssize_t. }
  PPy_ssize_t = ^Py_ssize_t;

  { Тип для хранения хеш-значений (эквивалент `Py_hash_t` в C). }
  Py_hash_t = Py_ssize_t;

  { Тип для представления символов Unicode в кодировке Latin-1 (1 байт). }
  Py_UCS1  = uint8_t;
  { Указатель на Py_UCS1. }
  PPy_UCS1 = ^Py_UCS1;
  { Тип для представления символов Unicode в кодировке UCS-2 (2 байта). }
  Py_UCS2  = uint16_t;
  { Указатель на Py_UCS2. }
  PPy_UCS2 = ^Py_UCS2;
  { Тип для представления символов Unicode в кодировке UCS-4 (4 байта). }
  Py_UCS4  = uint32_t;
  { Указатель на Py_UCS4. }
  PPy_UCS4 = ^Py_UCS4;

  { Представляет состояние Global Interpreter Lock (GIL) для текущего потока. }
  PyGILState_STATE = cint;

const
  {$IFDEF CPU64}
    {$IFDEF WINDOWS}
      PY_SSIZE_T_MAX = High(Int64); // = 9223372036854775807 (LLONG_MAX)
    {$ELSE}
      PY_SSIZE_T_MAX = High(PtrInt); // = 9223372036854775807 на 64-bit Unix
    {$ENDIF}
  {$ELSE}
  PY_SSIZE_T_MAX = High(longint); // = 2147483647 (INT_MAX)
  {$ENDIF}


  // ---------------------- Method Flags (ml_flags) -----------------------------
  // --- Method Flags (ml_flags) ---
  {
    Флаги, определяющие сигнатуру и способ вызова C-функции, реализующей метод.
    Используются в поле `ml_flags` структуры `PyMethodDef`.
  }

  {
    Сигнатура `PyCFunction`.
    Метод принимает `self` и кортеж `args`.
  }
  METH_VARARGS = $0001;

  {
    Сигнатура `PyCFunctionWithKeywords`.
    Метод принимает `self`, кортеж `args` и словарь `kwargs`.
    Если этот флаг используется, `METH_VARARGS` также должен быть установлен.
  }
  METH_KEYWORDS = $0002;

  {
    Сигнатура `PyCFunction`.
    Метод не принимает аргументов (только `self`).
  }
  METH_NOARGS = $0004;

  {
    Сигнатура `PyCFunction`.
    Метод принимает один объектный аргумент.
  }
  METH_O = $0008;

  // ---------------------- Type Flags (tp_flags) -----------------------------
  // --- Type Flags (tp_flags) ---
  {
    Битовые флаги, определяющие возможности и поведение типа.
    Используются в поле `tp_flags` структуры `PyTypeObject`.
    Для проверки флага используйте `PyType_HasFeature()`.
  }
  {$IFNDEF PY_LIMITED_API}
  { Внутренний флаг: отслеживает типы, инициализированные через `_PyStaticType_InitBuiltin`. }
  _Py_TPFLAGS_STATIC_BUILTIN = 1 shl 1;

  { Указывает, что массив значений размещён встраиваемо (inline) сразу после объекта. Подразумевает `Py_TPFLAGS_HAVE_GC`. }
  Py_TPFLAGS_INLINE_VALUES = 1 shl 2;

  { Указывает, что размещением weakref-указателей управляет виртуальная машина. Подразумевает `Py_TPFLAGS_HAVE_GC`. }
  Py_TPFLAGS_MANAGED_WEAKREF = 1 shl 3;

  { Указывает, что размещением dict-указателей управляет виртуальная машина. Подразумевает `Py_TPFLAGS_HAVE_GC`. }
  Py_TPFLAGS_MANAGED_DICT = 1 shl 4;

  { Комбинация `Py_TPFLAGS_MANAGED_WEAKREF` и `Py_TPFLAGS_MANAGED_DICT`. }
  Py_TPFLAGS_PREHEADER = Py_TPFLAGS_MANAGED_WEAKREF or Py_TPFLAGS_MANAGED_DICT;

  { Указывает, что экземпляры типа могут рассматриваться как последовательности при сопоставлении с шаблоном (`match`). }
  Py_TPFLAGS_SEQUENCE = 1 shl 5;

  { Указывает, что экземпляры типа могут рассматриваться как отображения (`mapping`) при сопоставлении с шаблоном. }
  Py_TPFLAGS_MAPPING  = 1 shl 6;
  {$ENDIF}
  { Запрещает создание экземпляров типа (устанавливает `tp_new` в `NULL`). }
  Py_TPFLAGS_DISALLOW_INSTANTIATION = 1 shl 7;
  { Указывает, что тип является неизменяемым: атрибуты нельзя установить или удалить. }
  Py_TPFLAGS_IMMUTABLETYPE = 1 shl 8;
  { Указывает, что тип создан динамически (в "куче"). }
  Py_TPFLAGS_HEAPTYPE = 1 shl 9;
  { Указывает, что тип может быть использован как базовый для других типов. }
  Py_TPFLAGS_BASETYPE = 1 shl 10;
  { Указывает, что тип реализует протокол vectorcall (PEP 590). }
  {$IFNDEF PY_LIMITED_API}
  Py_TPFLAGS_HAVE_VECTORCALL = 1 shl 11;
  _Py_TPFLAGS_HAVE_VECTORCALL = Py_TPFLAGS_HAVE_VECTORCALL;
  // Псевдоним для обратной совместимости
  {$ENDIF}
  { Указывает, что тип полностью инициализирован (`PyType_Ready` был вызван). }
  Py_TPFLAGS_READY    = 1 shl 12;
  { Внутренний флаг: тип находится в процессе инициализации (`PyType_Ready`). }
  Py_TPFLAGS_READYING = 1 shl 13;
  { Указывает, что объекты этого типа поддерживают сборку мусора. }
  Py_TPFLAGS_HAVE_GC  = 1 shl 14;
  { Зарезервировано для Stackless Python. }
  {$ifdef STACKLESS}
  Py_TPFLAGS_HAVE_STACKLESS_EXTENSION = 3 shl 15;
  {$else}
  Py_TPFLAGS_HAVE_STACKLESS_EXTENSION = 0;
  {$endif}
  { Указывает, что объекты типа ведут себя как несвязанные методы. }
  Py_TPFLAGS_METHOD_DESCRIPTOR = 1 shl 17;
  { Устаревший флаг, не используется. }
  Py_TPFLAGS_VALID_VERSION_TAG = 1 shl 19;
  { Указывает, что тип является абстрактным и не может быть инстанциирован. }
  Py_TPFLAGS_IS_ABSTRACT = 1 shl 20;
  { Внутренний флаг для особого поведения встроенных типов при сопоставлении с шаблоном. }
  _Py_TPFLAGS_MATCH_SELF = 1 shl 22;
  { Указывает, что элементы (`ob_size` * `tp_itemsize`) находятся в конце экземпляра. }
  Py_TPFLAGS_ITEMS_AT_END = 1 shl 23;

  // --- Subclass Flags ---
  {
    Флаги для быстрой проверки, является ли тип подклассом
    одного из встроенных базовых типов.
  }
  { Установлен для `long` и его подклассов. }
  Py_TPFLAGS_LONG_SUBCLASS     = 1 shl 24;
  { Установлен для `list` и его подклассов. }
  Py_TPFLAGS_LIST_SUBCLASS     = 1 shl 25;
  { Установлен для `tuple` и его подклассов. }
  Py_TPFLAGS_TUPLE_SUBCLASS    = 1 shl 26;
  { Установлен для `bytes` и его подклассов. }
  Py_TPFLAGS_BYTES_SUBCLASS    = 1 shl 27;
  { Установлен для `unicode` и его подклассов. }
  Py_TPFLAGS_UNICODE_SUBCLASS  = 1 shl 28;
  { Установлен для `dict` и его подклассов. }
  Py_TPFLAGS_DICT_SUBCLASS     = 1 shl 29;
  { Установлен для `BaseException` и его подклассов. }
  Py_TPFLAGS_BASE_EXC_SUBCLASS = 1 shl 30;
  { Установлен для `type` и его подклассов. }
  Py_TPFLAGS_TYPE_SUBCLASS     = 1 shl 31;

  {
    Флаги по умолчанию для нового типа.
    Включает базовые флаги, необходимые для всех типов.
  }
  Py_TPFLAGS_DEFAULT = Py_TPFLAGS_HAVE_STACKLESS_EXTENSION;

  // --- Backward Compatibility Flags ---
  {
    Эти флаги сохранены для совместимости со старыми расширениями,
    использующими стабильный ABI, и не должны использоваться в новом коде.
  }
  { Указывает на наличие поля `tp_finalize`. }
  Py_TPFLAGS_HAVE_FINALIZE    = 1 shl 0;
  { Указывает на наличие поля `tp_version_tag`. }
  Py_TPFLAGS_HAVE_VERSION_TAG = 1 shl 18;

type
  // ---------------------- Pointer Types -----------------------------
  { Указатель на структуру `PyTypeObject`. }
  PPyTypeObject = ^PyTypeObject;
  { Указатель на структуру `PyObject`. }
  PPyObject     = ^PyObject;
  { Указатель на указатель на `PyObject` (используется для передачи по ссылке). }
  PPPyObject    = ^PPyObject;
  { Указатель на структуру `Py_buffer`. }
  PPy_buffer    = ^Py_buffer;

  // --- Function Types (Callbacks) ---
  {
    Сигнатура `PyCFunction`: базовый тип для функций, реализующих методы
    с флагом `METH_VARARGS`. Принимает `self` и кортеж аргументов `args`.
  }
  PyCFunction = function(self, args: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `getter`: функция для получения значения атрибута.
    Используется в `PyGetSetDef`.
  }
  getter = function(obj: PPyObject; closure: Pointer): PPyObject; cdecl;

  {
    Сигнатура `setter`: функция для установки значения атрибута.
    Используется в `PyGetSetDef`.
  }
  setter = function(obj: PPyObject; Value: PPyObject; closure: Pointer): cint; cdecl;

  {
    Сигнатура `destructor`: деструктор объекта.
    Используется в `tp_dealloc`, `tp_free`, `tp_del`, `tp_finalize`.
  }
  pydestructor = procedure(ob: PPyObject); cdecl;

  {
    Сигнатура `getattrfunc`: функция для получения атрибута по имени (устаревший стиль).
    Используется в `tp_getattr`.
  }
  getattrfunc = function(ob1: PPyObject; Name: pansichar): PPyObject; cdecl;

  {
    Сигнатура `setattrfunc`: функция для установки атрибута по имени (устаревший стиль).
    Используется в `tp_setattr`.
  }
  setattrfunc = function(ob1: PPyObject; Name: pansichar; ob2: PPyObject): cint; cdecl;

  {
    Сигнатура `reprfunc`: функция для `repr()` и `str()`.
    Используется в `tp_repr`, `tp_str`.
  }
  reprfunc = function(ob: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `hashfunc`: функция для `hash()`.
    Используется в `tp_hash`.
  }
  hashfunc = function(ob: PPyObject): Py_hash_t; cdecl;

  {
    Сигнатура `ternaryfunc`: функция, принимающая три объекта.
    Используется для `pow()`, `__call__` и др.
  }
  ternaryfunc = function(ob1, ob2, ob3: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `getattrofunc`: функция для `getattr()`.
    Используется в `tp_getattro`.
  }
  getattrofunc = function(ob1, ob2: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `setattrofunc`: функция для `setattr()`.
    Используется в `tp_setattro`.
  }
  setattrofunc = function(ob1, ob2, ob3: PPyObject): cint; cdecl;

  {
    Сигнатура `objobjargproc`: процедура, принимающая три объекта.
    Используется в `mp_ass_subscript`.
  }
  objobjargproc = function(obj1, obj2, obj3: PPyObject): cint; cdecl;

  {
    Сигнатура `traverseproc`: функция для обхода объекта сборщиком мусора.
    Используется в `tp_traverse`.
  }
  traverseproc = function(ob1: PPyObject; proc: Pointer; ptr: Pointer): cint; cdecl;

  {
    Сигнатура `inquiry`: функция, возвращающая `cint` (обычно 0/1 или длину).
    Используется в `tp_clear`, `tp_is_gc`, `nb_bool`, `sq_length`.
  }
  inquiry = function(ob1: PPyObject): cint; cdecl;

  {
    Сигнатура `richcmpfunc`: функция для "богатых" сравнений.
    Используется в `tp_richcompare`.
  }
  richcmpfunc = function(ob1, ob2: PPyObject; i: cint): PPyObject; cdecl;

  {
    Сигнатура `getiterfunc`: функция для `iter()`.
    Используется в `tp_iter`.
  }
  getiterfunc = function(ob1: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `iternextfunc`: функция для `next()`.
    Используется в `tp_iternext`.
  }
  iternextfunc = function(ob1: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `descrgetfunc`: функция-геттер для дескрипторов.
    Используется в `tp_descr_get`.
  }
  descrgetfunc = function(ob1, ob2, ob3: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `descrsetfunc`: функция-сеттер для дескрипторов.
    Используется в `tp_descr_set`.
  }
  descrsetfunc = function(ob1, ob2, ob3: PPyObject): cint; cdecl;

  {
    Сигнатура `initproc`: инициализатор (`__init__`).
    Используется в `tp_init`.
  }
  initproc = function(self, args, kwds: PPyObject): cint; cdecl;

  {
    Сигнатура `newfunc`: конструктор (`__new__`).
    Используется в `tp_new`.
  }
  newfunc = function(subtype: PPyTypeObject; args, kwds: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `allocfunc`: функция выделения памяти.
    Используется в `tp_alloc`.
  }
  allocfunc = function(self: PPyTypeObject; nitems: Py_ssize_t): PPyObject; cdecl;

  {
    Сигнатура `vectorcallfunc`: функция для протокола `vectorcall`.
    Используется в `tp_vectorcall`.
  }
  vectorcallfunc = function(callable: PPyObject; const args: PPPyObject;
    nargsf: csize_t; kwnames: PPyObject): PPyObject; cdecl;

  {
    Сигнатура `getbufferproc`: функция для получения буфера.
    Используется в `PyBufferProcs`.
  }
  getbufferproc = function(self: PPyObject; buffer: PPy_buffer; i: cint): cint; cdecl;

  {
    Сигнатура `releasebufferproc`: функция для освобождения буфера.
    Используется в `PyBufferProcs`.
  }
  releasebufferproc = procedure(self: PPyObject; buffer: PPy_buffer); cdecl;


  { Указатель на структуру `PyMethodDef`. }
  PPyMethodDef = ^PyMethodDef;
  {
    Структура, описывающая один метод в модуле или типе.
    Массив таких структур используется в `PyModuleDef` и `PyTypeObject`.
  }
  PyMethodDef  = record
    ml_name:  pansichar;    { Имя метода. }
    ml_meth:  PyCFunction;  { Указатель на C-функцию. }
    ml_flags: cint;         { Флаги вызова (`METH_*`). }
    ml_doc:   pansichar;    { Строка документации. }
  end;

  { Указатель на структуру `PyMemberDef`. }
  PPyMemberDef = ^PyMemberDef;
  {
    Структура, описывающая один член (атрибут) типа данных C.
    Используется для прямого доступа к полям структуры из Python.
  }
  PyMemberDef  = record
    Name:   pansichar;      { Имя члена. }
    _type:  cint;           { Тип данных (`T_INT`, `T_STRING` и т.д.). }
    offset: Py_ssize_t;
    { Смещение поля в байтах от начала структуры. }
    flags:  cint;          { Флаги доступа (`READONLY`). }
    doc:    pansichar;       { Строка документации. }
  end;

  { Указатель на структуру `PyGetSetDef`. }
  PPyGetSetDef = ^PyGetSetDef;
  {
    Структура, описывающая вычисляемый атрибут типа.
    Доступ к атрибуту осуществляется через функции `getter` и `setter`.
  }
  PyGetSetDef  = record
    Name:    pansichar;     { Имя атрибута. }
    get:     getter;        { Функция для получения значения (getter). }
    _set:    setter;        { Функция для установки значения (setter). }
    doc:     pansichar;     { Строка документации. }
    closure: Pointer;
    { Указатель на произвольные данные для передачи в getter/setter. }
  end;

  {
    Структура, предоставляющая C-уровневый доступ к памяти объекта
    через буферный протокол.
  }
  Py_buffer = record
    buf:      Pointer;         { Указатель на начало памяти. }
    obj:      PPyObject;       { Объект-владелец буфера. }
    len:      Py_ssize_t;      { Общий размер буфера в байтах. }
    itemsize: Py_ssize_t;      { Размер одного элемента в байтах. }
    ReadOnly: cint;       { `1`, если буфер только для чтения, иначе `0`. }
    ndim:     cint;
    { Количество измерений (рангов) массива. }
    format:   pansichar;    { Формат элемента в стиле модуля `struct`. }
    shape:    PPy_ssize_t;
    { Форма N-мерного массива (размеры каждого измерения). }
    strides:  PPy_ssize_t;
    { Шаги (в байтах) для каждого измерения. }
    suboffsets: PPy_ssize_t; { Для непрямых (indirect) массивов. }
    internal: Pointer;
    { Зарезервировано для внутреннего использования. }
  end;


  { Указатель на структуру `PyBufferProcs`. }
  PPyBufferProcs = ^PyBufferProcs;
  {
    Структура, содержащая указатели на функции буферного протокола.
    Используется в поле `tp_as_buffer` структуры `PyTypeObject`.
  }
  PyBufferProcs  = record
    bf_getbuffer:     getbufferproc;     { Функция для получения буфера. }
    bf_releasebuffer: releasebufferproc;
    { Функция для освобождения буфера. }
  end;

  // ----------- Core Object Structures -----------
  { Указатель на структуру `PyMutex`. }
  PPyMutex = ^PyMutex;
  {
    Лёгкий мьютекс CPython, используемый для синхронизации доступа
    к объектам в сборках без GIL.
  }
  PyMutex  = packed record
    _locked:  byte; { 0 - разблокирован, 1 - заблокирован. }
    {$IFDEF MSWINDOWS}
    // Выравнивание до размера указателя для совместимости с MSVC
    _aligner: packed array [0..SizeOf(Pointer) - 2] of byte;
  {$ENDIF}
  end;

  {
    Базовая структура для всех объектов Python.
    Все остальные объекты Python являются её расширениями.
  }
  {$IFDEF Py_GIL_DISABLED}
  // --- Структура PyObject для сборок без GIL ---
  PyObject = packed record
    ob_tid: uintptr_t;         { ID потока-владельца или указатель в GC. }
    ob_flags: uint16_t;        { Флаги объекта. }
    ob_mutex: PyMutex;         { Мьютекс для каждого объекта. }
    ob_gc_bits: uint8_t;       { Биты состояния для сборщика мусора. }
    ob_ref_local: uint32_t;    { Локальный (неатомарный) счетчик ссылок. }
    ob_ref_shared: Py_ssize_t; { Общий (атомарный) счетчик ссылок. }
    ob_type: PPyTypeObject;    { Указатель на объект типа. }
  end;
  {$ELSE}
  // --- Структура PyObject для стандартных сборок с GIL ---
  {$IF SizeOf(Pointer) <= 4}
  // --- 32-битная архитектура ---
  PyObject = packed record
    ob_refcnt: Py_ssize_t;      { Счетчик ссылок. }
    ob_type:   PPyTypeObject;   { Указатель на объект типа. }
  end;
  {$ELSE}
  // --- 64-битная архитектура ---
  PyObject = packed record
    {$IFDEF ENDIAN_BIG}
    // Порядок полей для Big-endian
    ob_flags: uint16_t;       { Флаги (e.g., _Py_IMMORTAL_FLAGS). }
    ob_overflow: uint16_t;    { Поле для обнаружения переполнения `ob_refcnt`. }
    ob_refcnt: uint32_t;      { Основная часть счетчика ссылок. }
    {$ELSE}
    // Порядок полей для Little-endian
    ob_refcnt: uint32_t;
    ob_overflow: uint16_t;
    ob_flags: uint16_t;
    {$ENDIF}
    ob_type: PPyTypeObject;   { Указатель на объект типа. }
    // Примечание: на 64-битных платформах `ob_refcnt`, `ob_overflow` и `ob_flags`
    // фактически образуют единое 64-битное поле для счетчика ссылок.
  end;
  {$ENDIF}
  {$ENDIF}

  { Указатель на структуру `PyVarObject`. }
  PPyVarObject = ^PyVarObject;
  {
    Расширение `PyObject` для объектов переменного размера (например, `list`, `tuple`).
    Добавляет поле `ob_size`, хранящее количество элементов.
  }
  PyVarObject  = record
    ob_base: PyObject;     { Заголовок, унаследованный от `PyObject`. }
    ob_size: Py_ssize_t;
    { Количество элементов в переменной части. }
  end;

  { Указатель на структуру `PyNumberMethods`. }
  PPyNumberMethods = ^PyNumberMethods;
  {
    Структура, содержащая указатели на функции, реализующие числовые протоколы.
    Используется в поле `tp_as_number` структуры `PyTypeObject`.
  }
  PyNumberMethods  = record
    nb_add:   ternaryfunc;                   { `+` }
    nb_subtract: ternaryfunc;                { `-` }
    nb_multiply: ternaryfunc;                { `*` }
    nb_remainder: ternaryfunc;               { `%` }
    nb_divmod: ternaryfunc;                  { `divmod()` }
    nb_power: ternaryfunc;                   { `pow()` }
    nb_negative: reprfunc;                   { `-` (унарный) }
    nb_positive: reprfunc;                   { `+` (унарный) }
    nb_absolute: reprfunc;                   { `abs()` }
    nb_bool:  inquiry;                       { `bool()` }
    nb_invert: reprfunc;                     { `~` }
    nb_lshift: ternaryfunc;                  { `<<` }
    nb_rshift: ternaryfunc;                  { `>>` }
    nb_and:   ternaryfunc;                   { `&` }
    nb_xor:   ternaryfunc;                   { `^` }
    nb_or:    ternaryfunc;                   { `|` }
    nb_int:   reprfunc;                      { `int()` }
    nb_reserved: Pointer;
    { Внутреннее использование (ранее `nb_long`). }
    nb_float: reprfunc;                   { `float()` }
    nb_inplace_add: ternaryfunc;          { `+=` }
    nb_inplace_subtract: ternaryfunc;     { `-=` }
    nb_inplace_multiply: ternaryfunc;     { `*=` }
    nb_inplace_remainder: ternaryfunc;    { `%=` }
    nb_inplace_power: ternaryfunc;        { `**=` }
    nb_inplace_lshift: ternaryfunc;       { `<<=` }
    nb_inplace_rshift: ternaryfunc;       { `>>=` }
    nb_inplace_and: ternaryfunc;          { `&=` }
    nb_inplace_xor: ternaryfunc;          { `^=` }
    nb_inplace_or: ternaryfunc;           { `|=` }
    nb_floor_divide: ternaryfunc;         { `//` }
    nb_true_divide: ternaryfunc;          { `/` }
    nb_inplace_floor_divide: ternaryfunc; { `//=` }
    nb_inplace_true_divide: ternaryfunc;  { `/=` }
    nb_index: reprfunc;                   { `operator.index()` }
    nb_matrix_multiply: ternaryfunc;      { `@` }
    nb_inplace_matrix_multiply: ternaryfunc; { `@=` }
  end;

  { Указатель на структуру `PySequenceMethods`. }
  PPySequenceMethods = ^PySequenceMethods;
  {
    Структура, содержащая указатели на функции, реализующие протоколы последовательностей.
    Используется в поле `tp_as_sequence` структуры `PyTypeObject`.
  }
  PySequenceMethods  = record
    sq_length:   inquiry;             { `len()` }
    sq_concat:   ternaryfunc;         { `+` }
    sq_repeat:   descrgetfunc;        { `*` }
    sq_item:     descrgetfunc;        { `__getitem__` }
    sq_ass_item: descrsetfunc;        { `__setitem__` }
    sq_contains: inquiry;             { `in` }
    sq_inplace_concat: ternaryfunc;   { `+=` }
    sq_inplace_repeat: descrgetfunc;  { `*=` }
  end;

  { Указатель на структуру `PyMappingMethods`. }
  PPyMappingMethods = ^PyMappingMethods;
  {
    Структура, содержащая указатели на функции, реализующие протоколы отображений (mapping).
    Используется в поле `tp_as_mapping` структуры `PyTypeObject`.
  }
  PyMappingMethods  = record
    mp_length:    inquiry;           { `len()` }
    mp_subscript: ternaryfunc;       { `__getitem__` }
    mp_ass_subscript: objobjargproc; { `__setitem__` }
  end;


  {
    Структура, определяющая новый тип Python.
    Она содержит всю информацию, необходимую для описания поведения типа:
    имя, размеры экземпляра, таблицы методов, обработчики атрибутов,
    протоколы выделения памяти, наследования, сборки мусора и т.п.
  }
  PyTypeObject = record
    ob_base:      PyVarObject;
    { Заголовок, унаследованный от PyVarObject. }
    tp_name:      pansichar;
    { Имя типа в формате "<module>.<name>". }
    tp_basicsize: Py_ssize_t;          { Размер экземпляра в байтах. }
    tp_itemsize:  Py_ssize_t;
    { Размер элемента для объектов переменного размера (если > 0). }

    { Методы для реализации стандартных операций }
    tp_dealloc:  pydestructor;          { Деструктор. }
    tp_vectorcall_offset: Py_ssize_t;  { Смещение к функции `vectorcall`. }
    tp_as_async: Pointer;
    { Указатель на `PyAsyncMethods` для `await`, `aiter`, `anext`. }
    tp_repr:     reprfunc;                 { Функция для `repr()`. }

    { Наборы методов для стандартных классов }
    tp_as_number:   PPyNumberMethods;    { Числовые методы. }
    tp_as_sequence: PPySequenceMethods; { Методы последовательности. }
    tp_as_mapping:  PPyMappingMethods;  { Методы отображения. }

    { Другие стандартные операции }
    tp_hash:     hashfunc;                 { Функция для `hash()`. }
    tp_call:     ternaryfunc;
    { Функция для вызова объекта `obj(...)`. }
    tp_str:      reprfunc;                  { Функция для `str()`. }
    tp_getattro: getattrofunc;
    { Функция для получения атрибута (`getattr`). }
    tp_setattro: setattrofunc;
    { Функция для установки атрибута (`setattr`). }

    { Функции для доступа к объекту как к буферу }
    tp_as_buffer: PPyBufferProcs;      { Методы буферного протокола. }

    { Флаги для определения наличия опциональных/расширенных возможностей }
    tp_flags: culong;                    { Битовые флаги (`Py_TPFLAGS_*`). }
    tp_doc:   pansichar;                 { Строка документации (`__doc__`). }

    { Сборка мусора }
    tp_traverse: traverseproc;
    { Обход объекта сборщиком мусора. }
    tp_clear:    inquiry;                 { Очистка внутренних ссылок. }

    { Другие атрибуты, доступные только через публичные API }
    tp_richcompare:    richcmpfunc;
    { "Богатые" сравнения (`==`, `!=`, `<`, `>`). }
    tp_weaklistoffset: Py_ssize_t;
    { Смещение к списку слабых ссылок. }

    { Итераторы }
    tp_iter:     getiterfunc;              { Получение итератора (`iter()`). }
    tp_iternext: iternextfunc;
    { Получение следующего элемента итератора (`next()`). }

    { Дескрипторы атрибутов и наследование }
    tp_methods:   PPyMethodDef;          { Массив методов типа. }
    tp_members:   PPyMemberDef;          { Массив членов типа. }
    tp_getset:    PPyGetSetDef;
    { Массив вычисляемых атрибутов. }
    tp_base:      PPyTypeObject;            { Базовый тип. }
    tp_dict:      PPyObject;
    { Словарь атрибутов типа (`__dict__`). }
    tp_descr_get: descrgetfunc;
    { Геттер для дескрипторов (`__get__`). }
    tp_descr_set: descrsetfunc;
    { Сеттер для дескрипторов (`__set__`). }
    tp_dictoffset: Py_ssize_t;
    { Смещение к словарю экземпляра (`__dict__`). }

    tp_init:  initproc;                 { Инициализатор (`__init__`). }
    tp_alloc: allocfunc;                { Функция выделения памяти. }
    tp_new:   newfunc;
    { Функция создания экземпляра (`__new__`). }
    tp_free:  pydestructor;
    { Низкоуровневое освобождение памяти. }
    tp_is_gc: inquiry;
    { Проверка, отслеживается ли объект GC. }

    tp_bases:    PPyObject;               { Кортеж базовых типов (`__bases__`). }
    tp_mro:      PPyObject;
    { Порядок разрешения методов (`__mro__`). }
    tp_cache:    Pointer;                 { Внутренний кэш. }
    tp_subclasses: Pointer;            { Список подклассов. }
    tp_weaklist: PPyObject;            { Список слабых ссылок на тип. }

    { Тег версии кэша атрибутов типа }
    tp_version_tag: cuint;
    tp_finalize:    pydestructor;         { Финализатор. }
    tp_vectorcall:  vectorcallfunc;       { Указатель на функцию `vectorcall`. }

    { Поля, используемые только если тип является per-module классом }
    tp_watched: cuchar;
    tp_versions_used: cushort;

    { Поля, используемые только если тип имеет флаг Py_TPFLAGS_INLINE_VALUES }
    tp_valordictoffset:      Py_ssize_t;
    tp_valormetaclassoffset: Py_ssize_t;
    tp_valorwarnoffset:      Py_ssize_t;

    { Поля, используемые только если тип имеет флаг Py_TPFLAGS_MANAGED_DICT }
    tp_managed_dict:     PPPyObject; // PyObject**
    tp_managed_dict_set: function(dict_ptr: PPPyObject; Value: PPyObject): cint; cdecl;

    tp_slots: Pointer;

    { Это поле используется для разрешения tp_base в конце PyType_Ready() }
    tp_base_token: Pointer;
  end;


  { Указатель на структуру `Py_Identifier`. }
  PPy_Identifier = ^Py_Identifier;
  {
    Структура для управления статическими строками-идентификаторами.
    Используется для оптимизации доступа к атрибутам через ленивое
    интернирование строк.
  }
  Py_Identifier  = record
    str:   PChar;       { Строковое представление идентификатора. }
    index: Py_ssize_t;
    { Внутренний индекс в кэше (-1, если не инициализирован). }
    mutex: record       { Мьютекс для потокобезопасной инициализации. }
      v: uint8_t;
      end;
  end;

const
  // --- Internal Flags and Constants ---
  { Флаг бессмертного объекта (игнорируется сборщиком мусора). }
  _Py_IMMORTAL_FLAGS = 1 shl 0;
  { Флаг статически размещенного объекта. }
  _Py_STATICALLY_ALLOCATED_FLAG = 1 shl 2;

  {$IFDEF Py_GIL_DISABLED}
  { Начальное значение локального счетчика ссылок для "бессмертных" объектов в No-GIL. }
  _Py_IMMORTAL_REFCNT_LOCAL = High(uint32);
  {$ENDIF}

  {
    Начальное значение счетчика ссылок для статических "бессмертных" объектов.
    Используется для инициализации встроенных типов и синглтонов.
  }
  {$IF SizeOf(Pointer) > 4}// 64-bit
  _Py_IMMORTAL_INITIAL_REFCNT = 3 shl 30;
  _Py_STATIC_FLAG_BITS = _Py_IMMORTAL_FLAGS or _Py_STATICALLY_ALLOCATED_FLAG;
  _Py_STATIC_IMMORTAL_INITIAL_REFCNT =
    CUInt64(_Py_IMMORTAL_INITIAL_REFCNT) or (CUInt64(_Py_STATIC_FLAG_BITS) shl 48);
  {$ELSE} // 32-bit
  _Py_STATIC_IMMORTAL_INITIAL_REFCNT = 7 shl 28;
  {$ENDIF}

  // --- Built-in Constant IDs ---
  {
    Идентификаторы встроенных констант.
    Используются с `Py_GetConstant` и `Py_GetConstantBorrowed`.
  }
  { `None` }
  Py_CONSTANT_NONE     = 0;
  { `False` }
  Py_CONSTANT_FALSE    = 1;
  { `True` }
  Py_CONSTANT_TRUE     = 2;
  { `Ellipsis` (...) }
  Py_CONSTANT_ELLIPSIS = 3;
  { `NotImplemented` }
  Py_CONSTANT_NOT_IMPLEMENTED = 4;
  { `0` (int) }
  Py_CONSTANT_ZERO     = 5;
  { `1` (int) }
  Py_CONSTANT_ONE      = 6;
  { `''` (пустая строка) }
  Py_CONSTANT_EMPTY_STR = 7;
  { `b''` (пустые байты) }
  Py_CONSTANT_EMPTY_BYTES = 8;
  { `()` (пустой кортеж) }
  Py_CONSTANT_EMPTY_TUPLE = 9;


var
  // --- Version and Initialization ---
  { Возвращает строку с версией Python. }
  Py_GetVersion: function: pansichar; cdecl;

  // --- Type Operations ---
  { Возвращает поле `tp_flags` типа. }
  PyType_GetFlags: function(tp: PPyTypeObject): culong; cdecl;
  { Проверяет, является ли тип `a` подтипом `b`. }
  PyType_IsSubtype: function(a, b: PPyTypeObject): cbool; cdecl;

  // --- Threading and GIL ---
  { Блокирует мьютекс (для сборок No-GIL). }
  PyMutex_Lock: procedure(m: PPyMutex); cdecl;
  { Разблокирует мьютекс (для сборок No-GIL). }
  PyMutex_Unlock: procedure(m: PPyMutex); cdecl;
  {$IFNDEF PY_3.13}
  { Проверяет, заблокирован ли мьютекс (для сборок No-GIL). }
  PyMutex_IsLocked: function(m: PPyMutex): cbool; cdecl;
  {$ENDIF}
  { Проверяет, удерживается ли GIL. }
  PyGILState_Check: function: cint; cdecl;
  { Захватывает GIL. }
  PyGILState_Ensure: function(): PyGILState_STATE; cdecl;
  { Освобождает GIL. }
  PyGILState_Release: procedure(state: PyGILState_STATE); cdecl;

  // --- Reference Counting ---
  { Увеличивает счетчик ссылок объекта. }
  Py_IncRef: procedure(obj: PPyObject); cdecl;
  { Уменьшает счетчик ссылок объекта. }
  Py_DecRef: procedure(obj: PPyObject); cdecl;

  // --- Object Operations ---
  { Инициализирует заголовок объекта. }
  PyObject_Init: function(op: PPyObject; typeobj: PPyTypeObject): PPyObject; cdecl;
  { Проверяет наличие атрибута. }
  PyObject_HasAttr: function(o: PPyObject; attr_name: PPyObject): cint; cdecl;
  { Проверяет наличие атрибута по имени C-строки. }
  PyObject_HasAttrString: function(o: PPyObject; const attr_name: pansichar): cint; cdecl;
  { Удаляет атрибут. }
  PyObject_DelAttr: function(o: PPyObject; attr_name: PPyObject): cint; cdecl;
  { Удаляет атрибут по имени C-строки. }
  PyObject_DelAttrString: function(o: PPyObject; const attr_name: pansichar): cint; cdecl;
  { Получает атрибут по имени C-строки. }
  PyObject_GetAttrString: function(o: PPyObject; const attr_name: pansichar): PPyObject; cdecl;
  { Устанавливает атрибут по имени C-строки. }
  PyObject_SetAttrString: function(ob: PPyObject; key: pansichar;
  Value: PPyObject): integer; cdecl;

  // --- Standard Objects and Error Handling ---
  { Проверяет, является ли объект синглтоном `None`. }
  Py_IsNone: function(x: PPyObject): cbool; cdecl;
  { Очищает индикатор ошибки. }
  PyErr_Clear: procedure; cdecl;

  // --- Built-in Constants (Limited API) ---
  {$IFDEF Py_LIMITED_API}
  { Получает константу как "borrowed reference". }
  Py_GetConstantBorrowed: function(constant_id: cuint): PPyObject; cdecl;
  { Получает константу как "new reference". }
  Py_GetConstant: function(constant_id: cuint): PPyObject; cdecl;
  {$ENDIF}

  { Указатель на синглтон `None`. }
  Py_None: PPyObject;

// ---------------------- API Macros (inline functions) -----------------------------
{ Безопасно приводит произвольный указатель к `PPyObject`. Аналог `_PyObject_CAST` в C. }
function _PyObject_CAST(ob: Pointer): PPyObject; inline;
{ Возвращает указатель на тип объекта `o`. Аналог `Py_TYPE` в C. }
function Py_TYPE(o: PPyObject): PPyTypeObject; inline;
{ Проверяет, установлен ли у типа `o` указанный флаг `feature`. Аналог `PyType_HasFeature` в C. }
function PyType_HasFeature(o: PPyTypeObject; feature: culong): cbool; inline;
{ Быстрая проверка, является ли тип `o` подклассом с флагом `feature`. Аналог `PyType_FastSubclass` в C. }
function PyType_FastSubclass(o: PPyTypeObject; feature: culong): cbool; inline;
{ Проверяет, является ли тип объекта `ob` в точности `type`. Аналог `Py_IS_TYPE` в C. }
function Py_IS_TYPE(ob: PPyObject; tp: PPyTypeObject): cbool; inline;
{ Проверяет, что тип объекта `obj` совпадает с `t` или является его подтипом. Аналог `PyObject_TypeCheck` в C. }
function PyObject_TypeCheck(obj: PPyObject; t: PPyTypeObject): cbool; inline;
{ Уменьшает счётчик ссылок объекта, если указатель не `nil`. Аналог `Py_XDECREF` в C. }
procedure Py_XDECREF(op: PPyObject); inline;
{ Инициализирует заголовок `PyObject` для статических объектов. Аналог `PyObject_HEAD_INIT` в C. }
procedure PyObject_HEAD_INIT(obj: Pointer; ObType: PPyTypeObject); inline;


// ---------------------- Pascal Helper Functions ------------------
{$IFNDEF Py_GIL_DISABLED}
{
  Возвращает полный 64-битный счётчик ссылок для объекта в сборке с GIL.
  Эта функция необходима для работы с объединенными полями `ob_refcnt`,
  `ob_overflow` и `ob_flags` на 64-битных платформах.
}
function GetRefFull(const obj: PyObject): uint64_t; inline;
{$ENDIF}
{
  Загружает динамическую библиотеку Python и подготавливает var-функции
  для последующего вызова.
}
{
  Загружает динамическую библиотеку Python.
  Функция пытается загрузить библиотеку сначала для портативной версии
  (если установлен флаг `Py_PORTABLE`), а затем из стандартных системных путей.
}
procedure InitPythonAPI;
{
  Возвращает адрес функции/процедуры из загруженной библиотеки Python
  по её C-имени. При ошибке возвращает `nil`.
}
{
  Возвращает адрес функции из загруженной библиотеки Python по её имени.
  В режиме отладки выводит информацию об успешной или неуспешной загрузке.
}
function GetProc(const Name: pansichar): Pointer;

// --- Debug Output Helpers ---
{ Процедуры для вывода отладочной информации в консоль. }
procedure writeOk;
procedure writeError;
procedure writeDot;
procedure writeDel;
procedure writeBox;

implementation

uses
  DynLibs
  {$IFDEF Py_GIL_DISABLED}
 ,py_atomic_ext
  {$ENDIF}
  ;

const

  {хандл файла питон-библиотиеки}
  PythonLib: TLibHandle     = Default(TLibHandle);
  {Ссылка на объект, который в Python отображается как None.
   Доступ к нему следует осуществлять только с помощью функции Py_None,
   которая возвращает указатель на этот объект.}
  _Py_NoneStruct: PPyObject = Default(PPyObject);

procedure PyObject_HEAD_INIT(obj: Pointer; ObType: PPyTypeObject); inline;
var
  pyObj: PPyObject;
begin
  pyObj := PPyObject(obj);
  {$IFDEF Py_GIL_DISABLED}
  pyObj^.ob_tid := 0;
  pyObj^.ob_flags := _Py_STATICALLY_ALLOCATED_FLAG;
  pyObj^.ob_mutex := Default(PyMutex);
  pyObj^.ob_gc_bits := 0;
  pyObj^.ob_ref_local := _Py_IMMORTAL_REFCNT_LOCAL;
  pyObj^.ob_ref_shared := 0;
  pyObj^.ob_type := ObType;
  {$ELSE}
  {$IF SizeOf(Pointer) <= 4}
  pyObj^.ob_refcnt := _Py_STATIC_IMMORTAL_INITIAL_REFCNT;
  {$ELSE}
    {$IFDEF ENDIAN_BIG}
    PUInt64(@pyObj^.ob_flags)^ := _Py_STATIC_IMMORTAL_INITIAL_REFCNT;
    {$ELSE}
    PUInt64(@pyObj^.ob_refcnt)^ := _Py_STATIC_IMMORTAL_INITIAL_REFCNT;
    {$ENDIF}
  {$ENDIF}
  pyObj^.ob_type := ObType;
  {$ENDIF}
end;

function _PyObject_CAST(ob: Pointer): PPyObject;
begin
  Result := PPyObject(ob);
end;

function Py_TYPE(o: PPyObject): PPyTypeObject;
begin
  if Assigned(o) then
    Result := o^.ob_type
  else
    Result := nil;
end;

function PyType_HasFeature(o: PPyTypeObject; feature: culong): cbool;
begin
  {$IFDEF Py_LIMITED_API}
  Result := (PyType_GetFlags(o) and feature) <> 0;
  {$ELSE}
  Result := (o^.tp_flags and feature) <> 0;
  {$ENDIF}
end;

function PyType_FastSubclass(o: PPyTypeObject; feature: culong): cbool;
begin
  Result := PyType_HasFeature(o, feature);
end;

function Py_IS_TYPE(ob: PPyObject; tp: PPyTypeObject): cbool;
begin
  Result := Py_TYPE(ob) = tp;
end;

function PyObject_TypeCheck(obj: PPyObject; t: PPyTypeObject): cbool;
begin
  Result := Py_IS_TYPE(obj, t) or PyType_IsSubtype(Py_TYPE(obj), t);
end;

procedure Py_XDECREF(op: PPyObject);
begin
  if Assigned(op) then
    Py_DecRef(op);
end;

{$IFNDEF Py_GIL_DISABLED}
function GetRefFull(const obj: PyObject): uint64_t;
begin
  {$IFDEF ENDIAN_BIG}
  Result := PUInt64(@obj.ob_flags)^;
  {$ELSE}
  Result := PUInt64(@obj.ob_refcnt)^;
  {$ENDIF}
end;
{$ENDIF}

{
  Формирует полный путь к библиотеке Python для встраиваемой (portable) версии.
  Функция принимает путь к исполняемому файлу и индекс из массива `PythonFullNameAr`,
  чтобы построить путь к DLL/SO/DYLIB в той же директории.
}
function PythonDLLEmbedded(const PythonFullPath: ansistring; index: integer): ansistring;
var
  i, last: integer;
begin
  Result := '';
  last   := 0;
  for i := Length(PythonFullPath) downto 1 do
    {$IFDEF MSWINDOWS}
    if PythonFullPath[i] = '\' then
    {$ELSE}
    if PythonFullPath[i] = '/' then
    {$ENDIF}
    begin
      last := i;
      Break;
    end;
  Result := Copy(PythonFullPath, 1, last) + PythonFullNameAr[index];
end;

procedure InitPythonAPI;
var
  i: integer;
begin
  {$IFDEF Py_PORTABLE}
  for i := low(PythonFullNameAr) to high(PythonFullNameAr) do
  begin
    PythonLib := LoadLibrary(PythonDLLEmbedded(ParamStr(0), i));
    if PythonLib <> NilHandle then exit;
  end;
  {$IFDEF DEBUG}
  writeError;
  Writeln(PythonFullNameAr[i]);
  {$ENDIF}
  {$ENDIF}
  for i := low(PythonFullNameAr) to High(PythonFullNameAr) do
  begin
    PythonLib := LoadLibrary(PythonFullNameAr[i]);
    if PythonLib <> NilHandle then exit;
    {$IFDEF DEBUG}
    writeError;
    Writeln(PythonFullNameAr[i]);
    {$ENDIF}
  end;
end;

function GetProc(const Name: pansichar): Pointer;
begin
  Result := GetProcedureAddress(PythonLib, Name);
  {$IFDEF DEBUG}
  if Assigned(Result) then
    writeOk
  else
    writeError;
  writeln(Name);
  exit;
  {$ENDIF}
  {$IFDEF PY_CONSOLE}
  if not assigned(Result) then
    writeln('✗ ', Name);
  {$ENDIF}
end;

procedure writeOk;
begin
  Write('✓ ');
end;

procedure writeError;
begin
  Write('✗ ');
end;

procedure writeDot;
begin
  Write('.');
end;

procedure writeDel;
begin
  Write(#$E2#$8C#$AB, ' ');
end;

procedure writeBox;
begin
  Write('📦 ');
end;

var
  p: Pointer;

initialization
  InitPythonAPI;
  p := GetProc('PySys_WriteStdout');
  Pointer(Py_GetVersion) := GetProc('Py_GetVersion');

  {$IFDEF DEBUG}
  writeln('Compiler Version: ', {$I %FPCVERSION%});
  writeln('Compilation Date: ', {$I %DATE%});
  if Assigned(Py_GetVersion) then
    writeln('Python Version: ', Py_GetVersion)
  else
    writeln('Python Version: Not available');
  {$ENDIF}

  // --- Type Operations ---
  Pointer(PyType_GetFlags)  := GetProc('PyType_GetFlags');
  Pointer(PyType_IsSubtype) := GetProc('PyType_IsSubtype');

  // --- Threading and GIL ---
  Pointer(PyMutex_Lock)      := GetProc('PyMutex_Lock');
  Pointer(PyMutex_Unlock)    := GetProc('PyMutex_Unlock');
  {$IFNDEF PY_3.13}
  Pointer(PyMutex_IsLocked) := GetProc('PyMutex_IsLocked');
  {$ENDIF}
  Pointer(PyGILState_Check)  := GetProc('PyGILState_Check');
  Pointer(PyGILState_Ensure) := GetProc('PyGILState_Ensure');
  Pointer(PyGILState_Release) := GetProc('PyGILState_Release');

  // --- Reference Counting ---
  Pointer(Py_IncRef) := GetProc('Py_IncRef');
  Pointer(Py_DecRef) := GetProc('Py_DecRef');

  // --- Object Operations ---
  Pointer(PyObject_Init)    := GetProc('PyObject_Init');
  Pointer(PyObject_HasAttr) := GetProc('PyObject_HasAttr');
  Pointer(PyObject_HasAttrString) := GetProc('PyObject_HasAttrString');
  Pointer(PyObject_DelAttr) := GetProc('PyObject_DelAttr');
  Pointer(PyObject_DelAttrString) := GetProc('PyObject_DelAttrString');
  Pointer(PyObject_GetAttrString) := GetProc('PyObject_GetAttrString');
  Pointer(PyObject_SetAttrString) := GetProc('PyObject_SetAttrString');

  // --- Standard Objects and Error Handling ---
  Pointer(Py_IsNone)   := GetProc('Py_IsNone');
  Pointer(PyErr_Clear) := GetProc('PyErr_Clear');

  // --- Py_None Initialization ---
  {$IFDEF Py_LIMITED_API}
  Pointer(Py_GetConstantBorrowed) := GetProc('Py_GetConstantBorrowed');
  Pointer(Py_GetConstant) := GetProc('Py_GetConstant');
  if Assigned(Py_GetConstantBorrowed) then
    Py_None := Py_GetConstantBorrowed(Py_CONSTANT_NONE)
  else
    Py_None := nil;
  {$ELSE}
  Py_None := GetProc('_Py_NoneStruct');
  {$ENDIF}

finalization
  if PythonLib <> NilHandle then
  begin
    FreeLibrary(PythonLib);
    PythonLib := 0;
  end;
end.