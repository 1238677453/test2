{$mode objfpc}
{$I config.inc}
unit py_longobject;

interface

uses
  ctypes,
  python;

{
  Модуль для работы с объектами `int` (PyLongObject) в Python C API.

  Предоставляет функции для создания, преобразования и анализа
  целочисленных объектов Python.

  Целевая версия Python: 3.14
}

const
  // --- Native Bytes API Constants ---
  { Флаги для `PyLong_AsNativeBytes` и `PyLong_FromNativeBytes`. }
  Py_ASNATIVEBYTES_DEFAULTS = -1;       // Поведение по умолчанию
  Py_ASNATIVEBYTES_BIG_ENDIAN = 0;        // Big-endian
  Py_ASNATIVEBYTES_LITTLE_ENDIAN = 1;     // Little-endian
  Py_ASNATIVEBYTES_NATIVE_ENDIAN = 3;     // Порядок байт платформы
  Py_ASNATIVEBYTES_UNSIGNED_BUFFER = 4;   // Трактовать буфер как беззнаковый
  Py_ASNATIVEBYTES_REJECT_NEGATIVE = 8;   // Отвергать отрицательные значения
  Py_ASNATIVEBYTES_ALLOW_INDEX = 16;      // Разрешить `__index__()` для других типов

type
  {
    Внутреннее представление объекта `int` в CPython.
    В Limited API эта структура является непрозрачной.
  }
  PyLongObject = record
    ob_base: PyVarObject;
  end;
  PPyLongObject = ^PyLongObject;

var
  { Указатель на тип объекта `int`. }
  PyLong_Type: PPyTypeObject;

  // --- Creation from C types ---
  { Создаёт Python `int` из `clong`. }
  PyLong_FromLong: function(v: clong): PPyObject; cdecl;
  { Создаёт Python `int` из `culong`. }
  PyLong_FromUnsignedLong: function(v: culong): PPyObject; cdecl;
  { Создаёт Python `int` из `csize_t`. }
  PyLong_FromSize_t: function(v: csize_t): PPyObject; cdecl;
  { Создаёт Python `int` из `Py_ssize_t`. }
  PyLong_FromSsize_t: function(v: Py_ssize_t): PPyObject; cdecl;
  { Создаёт Python `int` из `cdouble`. }
  PyLong_FromDouble: function(v: cdouble): PPyObject; cdecl;
  { Создаёт Python `int` из `int64`. }
  PyLong_FromLongLong: function(v: int64): PPyObject; cdecl;
  { Создаёт Python `int` из `cuint64`. }
  PyLong_FromUnsignedLongLong: function(v: cuint64): PPyObject; cdecl;
  { Создаёт Python `int` из указателя. }
  PyLong_FromVoidPtr: function(p: Pointer): PPyObject; cdecl;
  
  // --- Creation from fixed-size C types (Python 3.13+) ---
  { Создаёт Python `int` из `cint32`. }
  PyLong_FromInt32: function(Value: cint32): PPyObject; cdecl;
  { Создаёт Python `int` из `cuint32`. }
  PyLong_FromUInt32: function(Value: cuint32): PPyObject; cdecl;
  { Создаёт Python `int` из `cint64`. }
  PyLong_FromInt64: function(Value: cint64): PPyObject; cdecl;
  { Создаёт Python `int` из `cuint64`. }
  PyLong_FromUInt64: function(Value: cuint64): PPyObject; cdecl;

  // --- Creation from strings and bytes ---
  { Создаёт `int` из байтового буфера. }
  PyLong_FromNativeBytes: function(buffer: Pointer; n_bytes: csize_t; flags: cint): PPyObject; cdecl;
  { Создаёт `int` из беззнакового байтового буфера. }
  PyLong_FromUnsignedNativeBytes: function(buffer: Pointer; n_bytes: csize_t; flags: cint): PPyObject; cdecl;
  { Создаёт `int` из C-строки. }
  PyLong_FromString: function(str: pansichar; endptr: PPAnsiChar; base: cint): PPyObject; cdecl;
  { Создаёт `int` из Python-строки. }
  PyLong_FromUnicodeObject: function(u: PPyObject; base: cint): PPyObject; cdecl;

  // --- Conversion to C types ---
  { Преобразует `int` в `clong`. }
  PyLong_AsLong: function(obj: PPyObject): clong; cdecl;
  { Преобразует `int` в `clong` с проверкой переполнения. }
  PyLong_AsLongAndOverflow: function(obj: PPyObject; overflow: Pcint): clong; cdecl;
  { Преобразует `int` в `Py_ssize_t`. }
  PyLong_AsSsize_t: function(obj: PPyObject): Py_ssize_t; cdecl;
  { Преобразует `int` в `csize_t`. }
  PyLong_AsSize_t: function(obj: PPyObject): csize_t; cdecl;
  { Преобразует `int` в `culong`. }
  PyLong_AsUnsignedLong: function(obj: PPyObject): culong; cdecl;
  { Преобразует `int` в `culong` с маскированием. }
  PyLong_AsUnsignedLongMask: function(obj: PPyObject): culong; cdecl;
  { Преобразует `int` в `int64`. }
  PyLong_AsLongLong: function(obj: PPyObject): int64; cdecl;
  { Преобразует `int` в `int64` с проверкой переполнения. }
  PyLong_AsLongLongAndOverflow: function(obj: PPyObject; overflow: Pcint): int64; cdecl;
  { Преобразует `int` в `cuint64`. }
  PyLong_AsUnsignedLongLong: function(obj: PPyObject): cuint64; cdecl;
  { Преобразует `int` в `cuint64` с маскированием. }
  PyLong_AsUnsignedLongLongMask: function(obj: PPyObject): cuint64; cdecl;
  { Преобразует `int` в `cdouble`. }
  PyLong_AsDouble: function(obj: PPyObject): cdouble; cdecl;
  { Преобразует `int` в указатель. }
  PyLong_AsVoidPtr: function(obj: PPyObject): Pointer; cdecl;
  { Копирует значение `int` в байтовый буфер. }
  PyLong_AsNativeBytes: function(v: PPyObject; buffer: Pointer; n_bytes: Py_ssize_t; flags: cint): Py_ssize_t; cdecl;

  // --- Conversion to fixed-size C types (Python 3.13+) ---
  { Преобразует `int` в `cint32`. }
  PyLong_AsInt32: function(obj: PPyObject; Value: Pcint32): cint; cdecl;
  { Преобразует `int` в `cuint32`. }
  PyLong_AsUInt32: function(obj: PPyObject; Value: Pcuint32): cint; cdecl;
  { Преобразует `int` в `cint64`. }
  PyLong_AsInt64: function(obj: PPyObject; Value: Pcint64): cint; cdecl;
  { Преобразует `int` в `cuint64`. }
  PyLong_AsUInt64: function(obj: PPyObject; Value: Pcuint64): cint; cdecl;
  
  // --- Utility Functions ---
  { Преобразует объект в `cint`. }
  PyLong_AsInt: function(obj: PPyObject): cint; cdecl;
  { Парсит строку в `culong`. }
  PyOS_strtoul: function(s: pansichar; endptr: PPAnsiChar; base: cint): culong; cdecl;
  { Парсит строку в `clong`. }
  PyOS_strtol: function(s: pansichar; endptr: PPAnsiChar; base: cint): clong; cdecl;
  { Возвращает информацию о внутреннем представлении `int`. }
  PyLong_GetInfo: function(): PPyObject; cdecl;

  {$IFNDEF PY_LIMITED_API}
  // --- Internal API ---
  { Возвращает знак `v`. }
  _PyLong_Sign: function(v: PPyObject): cint; cdecl;
  { Возвращает количество бит для представления `v`. }
  _PyLong_NumBits: function(v: PPyObject): Py_ssize_t; cdecl;
  { Создаёт `int` из массива байт. }
  _PyLong_FromByteArray: function(bytes: pbyte; n: csize_t; little_endian: cint; is_signed: cint): PPyObject; cdecl;
  { Конвертирует `int` в массив байт. }
  _PyLong_AsByteArray: function(v: PPyObject; bytes: pbyte; n: csize_t; little_endian: cint; is_signed: cint): cint; cdecl;
  { Проверяет, имеет ли `int` компактное представление. }
  PyUnstable_Long_IsCompact: function(op: PPyLongObject): cint; cdecl;
  {$ENDIF}

// --- Macros ---
{ Возвращает SHIFT из `sys.int_info`. }
function PyLong_SHIFT: cint; inline;
{ Возвращает BASE из `sys.int_info`. }
function PyLong_BASE: cint; inline;
{ Возвращает MASK из `sys.int_info`. }
function PyLong_MASK: cint; inline;
{ Возвращает BITS_PER_DIGIT из `sys.int_info`. }
function PyLong_BITS_PER_DIGIT: cint; inline;
{ Проверяет, является ли `op` типом `int` или его подтипом. }
function PyLong_Check(op: PPyObject): cbool; inline;
{ Проверяет, является ли `op` в точности типом `int`. }
function PyLong_CheckExact(op: PPyObject): cbool; inline;

implementation

var
  _LongInfoCached: cbool = False;
  _LongInfoShift: cint = -1;
  _LongInfoBase: cint = -1;
  _LongInfoMask: cint = -1;
  _LongInfoBitsPerDigit: cint = -1;

procedure _CacheLongInfo;
var
  info, value: PPyObject;
begin
  if _LongInfoCached then Exit;
  info := PyLong_GetInfo();
  if not Assigned(info) then Exit;

  value := PyObject_GetAttrString(info, 'shift');
  if Assigned(value) then _LongInfoShift := PyLong_AsInt(value);
  Py_XDECREF(value);

  value := PyObject_GetAttrString(info, 'base');
  if Assigned(value) then _LongInfoBase := PyLong_AsInt(value);
  Py_XDECREF(value);

  value := PyObject_GetAttrString(info, 'mask');
  if Assigned(value) then _LongInfoMask := PyLong_AsInt(value);
  Py_XDECREF(value);

  value := PyObject_GetAttrString(info, 'bits_per_digit');
  if Assigned(value) then _LongInfoBitsPerDigit := PyLong_AsInt(value);
  Py_XDECREF(value);

  Py_DECREF(info);
  _LongInfoCached := True;
end;

function PyLong_SHIFT: cint;
begin
  _CacheLongInfo;
  Result := _LongInfoShift;
end;

function PyLong_BASE: cint;
begin
  _CacheLongInfo;
  Result := _LongInfoBase;
end;

function PyLong_MASK: cint;
begin
  _CacheLongInfo;
  Result := _LongInfoMask;
end;

function PyLong_BITS_PER_DIGIT: cint;
begin
  _CacheLongInfo;
  Result := _LongInfoBitsPerDigit;
end;

function PyLong_Check(op: PPyObject): cbool;
begin
  Result := PyObject_TypeCheck(op, PyLong_Type);
end;

function PyLong_CheckExact(op: PPyObject): cbool;
begin
  Result := Py_IS_TYPE(op, PyLong_Type);
end;

initialization
  Pointer(PyLong_Type) := GetProc('PyLong_Type');

  Pointer(PyLong_FromLong) := GetProc('PyLong_FromLong');
  Pointer(PyLong_FromUnsignedLong) := GetProc('PyLong_FromUnsignedLong');
  Pointer(PyLong_FromSize_t) := GetProc('PyLong_FromSize_t');
  Pointer(PyLong_FromSsize_t) := GetProc('PyLong_FromSsize_t');
  Pointer(PyLong_FromDouble) := GetProc('PyLong_FromDouble');
  Pointer(PyLong_FromLongLong) := GetProc('PyLong_FromLongLong');
  Pointer(PyLong_FromUnsignedLongLong) := GetProc('PyLong_FromUnsignedLongLong');
  Pointer(PyLong_FromVoidPtr) := GetProc('PyLong_FromVoidPtr');
  
  Pointer(PyLong_FromInt32) := GetProc('PyLong_FromInt32');
  Pointer(PyLong_FromUInt32) := GetProc('PyLong_FromUInt32');
  Pointer(PyLong_FromInt64) := GetProc('PyLong_FromInt64');
  Pointer(PyLong_FromUInt64) := GetProc('PyLong_FromUInt64');

  Pointer(PyLong_FromNativeBytes) := GetProc('PyLong_FromNativeBytes');
  Pointer(PyLong_FromUnsignedNativeBytes) := GetProc('PyLong_FromUnsignedNativeBytes');
  Pointer(PyLong_FromString) := GetProc('PyLong_FromString');
  Pointer(PyLong_FromUnicodeObject) := GetProc('PyLong_FromUnicodeObject');
  
  Pointer(PyLong_AsLong) := GetProc('PyLong_AsLong');
  Pointer(PyLong_AsLongAndOverflow) := GetProc('PyLong_AsLongAndOverflow');
  Pointer(PyLong_AsSsize_t) := GetProc('PyLong_AsSsize_t');
  Pointer(PyLong_AsSize_t) := GetProc('PyLong_AsSize_t');
  Pointer(PyLong_AsUnsignedLong) := GetProc('PyLong_AsUnsignedLong');
  Pointer(PyLong_AsUnsignedLongMask) := GetProc('PyLong_AsUnsignedLongMask');
  Pointer(PyLong_AsLongLong) := GetProc('PyLong_AsLongLong');
  Pointer(PyLong_AsLongLongAndOverflow) := GetProc('PyLong_AsLongLongAndOverflow');
  Pointer(PyLong_AsUnsignedLongLong) := GetProc('PyLong_AsUnsignedLongLong');
  Pointer(PyLong_AsUnsignedLongLongMask) := GetProc('PyLong_AsUnsignedLongLongMask');
  Pointer(PyLong_AsDouble) := GetProc('PyLong_AsDouble');
  Pointer(PyLong_AsVoidPtr) := GetProc('PyLong_AsVoidPtr');
  Pointer(PyLong_AsNativeBytes) := GetProc('PyLong_AsNativeBytes');

  Pointer(PyLong_AsInt32) := GetProc('PyLong_AsInt32');
  Pointer(PyLong_AsUInt32) := GetProc('PyLong_AsUInt32');
  Pointer(PyLong_AsInt64) := GetProc('PyLong_AsInt64');
  Pointer(PyLong_AsUInt64) := GetProc('PyLong_AsUInt64');
  
  Pointer(PyLong_AsInt) := GetProc('PyLong_AsInt');
  Pointer(PyOS_strtoul) := GetProc('PyOS_strtoul');
  Pointer(PyOS_strtol) := GetProc('PyOS_strtol');
  Pointer(PyLong_GetInfo) := GetProc('PyLong_GetInfo');

  {$IFNDEF PY_LIMITED_API}
  Pointer(_PyLong_Sign) := GetProc('_PyLong_Sign');
  Pointer(_PyLong_NumBits) := GetProc('_PyLong_NumBits');
  Pointer(_PyLong_FromByteArray) := GetProc('_PyLong_FromByteArray');
  Pointer(_PyLong_AsByteArray) := GetProc('_PyLong_AsByteArray');
  Pointer(PyUnstable_Long_IsCompact) := GetProc('PyUnstable_Long_IsCompact');
  {$ENDIF}
end.
