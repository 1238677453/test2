{$mode fpc}
{$I config.inc}
{
  Модуль для работы с объектами `str` (PyUnicodeObject) в Python C API.

  Предоставляет функции для создания, кодирования, декодирования и
  манипулирования строковыми объектами Python.

  Целевая версия Python: 3.14
}
unit py_unicodeobject;

interface

uses
  ctypes, python, SysUtils
  {$IFDEF Py_GIL_DISABLED},
  py_atomic_ext
  {$ENDIF}
  ;

const
  // --- Internal State Flags ---
  { Состояния интернирования строк. }
  SSTATE_NOT_INTERNED = 0;
  SSTATE_INTERNED_MORTAL = 1;
  SSTATE_INTERNED_IMMORTAL = 2;

  { Битовые маски и сдвиги для поля `state.flags`. }
  STATE_INTERNED_MASK = $00000003;
  STATE_KIND_MASK = $0000001C;
  STATE_KIND_SHIFT = 2;
  STATE_COMPACT_BIT = $00000020;
  STATE_ASCII_BIT = $00000040;
  STATE_STATIC_BIT = $00000080;

  // --- Surrogate Code Points ---
  { Диапазоны суррогатных пар в Unicode. }
  Py_UNICODE_HIGH_SURROGATE_START = $D800;
  Py_UNICODE_HIGH_SURROGATE_END = $DBFF;
  Py_UNICODE_LOW_SURROGATE_START = $DC00;
  Py_UNICODE_LOW_SURROGATE_END = $DFFF;
  Py_UNICODE_SURROGATE_START = Py_UNICODE_HIGH_SURROGATE_START;
  Py_UNICODE_SURROGATE_END = Py_UNICODE_LOW_SURROGATE_END;

type
  { Вид (kind) внутреннего представления строки. }
  PyUnicodeKind = (
    PyUnicode_1BYTE_KIND = 1,
    PyUnicode_2BYTE_KIND = 2,
    PyUnicode_4BYTE_KIND = 4
  );

  P_PyUnicodeObject_state = ^_PyUnicodeObject_state;
  { Внутреннее состояние Unicode-объекта. }
  _PyUnicodeObject_state = packed record
    {$IFDEF Py_GIL_DISABLED}
    interned: uint8_t;
    _pad: array[0..2] of byte;
    flags: uint32_t;
    {$ELSE}
    flags: uint32_t;
    {$ENDIF}
  end;

  PPyASCIIObject = ^PyASCIIObject;
  { Базовая структура для всех Unicode-объектов. }
  PyASCIIObject = record
    ob_base: PyObject;
    length: Py_ssize_t;
    hash: Py_hash_t;
    state: _PyUnicodeObject_state;
  end;

  PPyCompactUnicodeObject = ^PyCompactUnicodeObject;
  { Структура для компактных (не-ASCII) строк. }
  PyCompactUnicodeObject = record
    _base: PyASCIIObject;
    utf8_length: Py_ssize_t;
    utf8: PChar;
  end;

  PPyUnicodeObject = ^PyUnicodeObject;
  { Структура для некомпактных строк. }
  PyUnicodeObject = record
    base: PyCompactUnicodeObject;
    case integer of
      0: (any: Pointer);
      1: (latin1: PPy_UCS1);
      2: (ucs2: PPy_UCS2);
      3: (ucs4: PPy_UCS4);
  end;

var
  // --- Types ---
  { Указатель на тип `str`. }
  PyUnicode_Type: PPyTypeObject;
  { Указатель на тип итератора по строке. }
  PyUnicodeIter_Type: PPyTypeObject;

  // --- Creation and Encoding ---
  { Создаёт строку из UTF-8 буфера. }
  PyUnicode_FromStringAndSize: function(const u: pansichar; size: Py_ssize_t): PPyObject; cdecl;
  { Создаёт строку из null-терминированной UTF-8 строки. }
  PyUnicode_FromString: function(const u: pansichar): PPyObject; cdecl;
  { Декодирует bytes-like объект. }
  PyUnicode_FromEncodedObject: function(obj: PPyObject; const encoding, errors: pansichar): PPyObject; cdecl;
  { Гарантированно возвращает `str`. }
  PyUnicode_FromObject: function(obj: PPyObject): PPyObject; cdecl;
  { Создаёт строку из одного символа. }
  PyUnicode_FromOrdinal: function(ordinal: cint): PPyObject; cdecl;
  { Создаёт новую, незаполненную строку. }
  PyUnicode_New: function(size: Py_ssize_t; maxchar: Py_UCS4): PPyObject; cdecl;
  { Создаёт строку из буфера с указанием `kind`. }
  PyUnicode_FromKindAndData: function(kind: PyUnicodeKind; const buffer: Pointer; size: Py_ssize_t): PPyObject; cdecl;

  // --- Formatting and Interning ---
  { Форматирование в стиле `printf`. }
  PyUnicode_FromFormat: function(const fmt: pansichar): PPyObject; cdecl; varargs;
  { Форматирование в стиле `printf` с `va_list`. }
  PyUnicode_FromFormatV: function(const fmt: pansichar; vargs: Pointer): PPyObject; cdecl;
  { Интернирует строку (in-place). }
  PyUnicode_InternInPlace: procedure(var s: PPyObject); cdecl;
  { Создаёт и интернирует строку. }
  PyUnicode_InternFromString: function(const u: pansichar): PPyObject; cdecl;

  // --- Data Access ---
  {$IFNDEF PY_LIMITED_API}
  { Возвращает подстроку. }
  PyUnicode_Substring: function(str: PPyObject; start, _end: Py_ssize_t): PPyObject; cdecl;
  { Возвращает длину строки. }
  PyUnicode_GetLength: function(unicode: PPyObject): Py_ssize_t; cdecl;
  { Читает символ по индексу. }
  PyUnicode_ReadChar: function(unicode: PPyObject; index: Py_ssize_t): Py_UCS4; cdecl;
  { Записывает символ по индексу. }
  PyUnicode_WriteChar: function(unicode: PPyObject; index: Py_ssize_t; character: Py_UCS4): cint; cdecl;
  {$ENDIF}
  { Изменяет размер строки. }
  PyUnicode_Resize: function(var unicode: PPyObject; length: Py_ssize_t): cint; cdecl;

  // --- Codecs ---
  { Возвращает кодировку по умолчанию. }
  PyUnicode_GetDefaultEncoding: function: pansichar; cdecl;
  { Декодирует байтовую строку. }
  PyUnicode_Decode: function(const s: pansichar; size: Py_ssize_t; const encoding, errors: pansichar): PPyObject; cdecl;
  { Кодирует строку в байты. }
  PyUnicode_AsEncodedString: function(unicode: PPyObject; const encoding, errors: pansichar): PPyObject; cdecl;
  { Декодирует UTF-8. }
  PyUnicode_DecodeUTF8: function(const s: pansichar; length: Py_ssize_t; const errors: pansichar): PPyObject; cdecl;
  { Декодирует UTF-8 с сохранением состояния. }
  PyUnicode_DecodeUTF8Stateful: function(const s: pansichar; length: Py_ssize_t; const errors: pansichar; consumed: PPy_ssize_t): PPyObject; cdecl;
  { Кодирует в UTF-8. }
  PyUnicode_AsUTF8String: function(unicode: PPyObject): PPyObject; cdecl;
  {$IFNDEF PY_LIMITED_API}
  { Кодирует в UTF-8 и возвращает размер. }
  PyUnicode_AsUTF8AndSize: function(unicode: PPyObject; size: PPy_ssize_t): pansichar; cdecl;
  {$ENDIF}

  // --- String Operations ---
  { Конкатенация строк. }
  PyUnicode_Concat: function(left, right: PPyObject): PPyObject; cdecl;
  { Добавление строки (in-place). }
  PyUnicode_Append: procedure(var left: PPyObject; right: PPyObject); cdecl;
  { Добавление строки с удалением правого операнда. }
  PyUnicode_AppendAndDel: procedure(var left: PPyObject; right: PPyObject); cdecl;
  { Поиск подстроки. }
  PyUnicode_Find: function(str_, substr: PPyObject; start, _end: Py_ssize_t; direction: cint): Py_ssize_t; cdecl;
  {$IFNDEF PY_LIMITED_API}
  { Поиск символа. }
  PyUnicode_FindChar: function(str_: PPyObject; ch: Py_UCS4; start, _end: Py_ssize_t; direction: cint): Py_ssize_t; cdecl;
  {$ENDIF}
  { Сравнение строк. }
  PyUnicode_Compare: function(left, right: PPyObject): cint; cdecl;
  { Сравнение с ASCII-строкой. }
  PyUnicode_CompareWithASCIIString: function(left: PPyObject; const right: pansichar): cint; cdecl;

// --- Macros ---
{ Приводит `PPyObject` к `PPyASCIIObject`. }
function _PyASCIIObject_CAST(op: PPyObject): PPyASCIIObject; inline;
{ Приводит `PPyObject` к `PPyCompactUnicodeObject`. }
function _PyCompactUnicodeObject_CAST(op: PPyObject): PPyCompactUnicodeObject; inline;
{ Приводит `PPyObject` к `PPyUnicodeObject`. }
function _PyUnicodeObject_CAST(op: PPyObject): PPyUnicodeObject; inline;

{ Проверяет, является ли `op` `str` или его подтипом. }
function PyUnicode_Check(op: PPyObject): cbool; inline;
{ Проверяет, является ли `op` в точности `str`. }
function PyUnicode_CheckExact(op: PPyObject): cbool; inline;
{ Возвращает состояние интернирования. }
function PyUnicode_CHECK_INTERNED(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка компактной ASCII. }
function PyUnicode_IS_COMPACT_ASCII(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка компактной. }
function PyUnicode_IS_COMPACT(op: PPyObject): cbool; inline;
{ Проверяет, содержит ли строка только ASCII. }
function PyUnicode_IS_ASCII(op: PPyObject): cbool; inline;

{ Возвращает `kind` строки. }
function PyUnicode_KIND(op: PPyObject): PyUnicodeKind; inline;
{ Возвращает длину строки. }
function PyUnicode_GET_LENGTH(op: PPyObject): Py_ssize_t; inline;
{ Возвращает указатель на данные строки. }
function PyUnicode_DATA(op: PPyObject): Pointer; inline;
{ Возвращает указатель на данные 1-байтовой строки. }
function PyUnicode_1BYTE_DATA(op: PPyObject): PPy_UCS1; inline;
{ Возвращает указатель на данные 2-байтовой строки. }
function PyUnicode_2BYTE_DATA(op: PPyObject): PPy_UCS2; inline;
{ Возвращает указатель на данные 4-байтовой строки. }
function PyUnicode_4BYTE_DATA(op: PPyObject): PPy_UCS4; inline;
{ Возвращает размер данных в байтах. }
function PyUnicode_GET_DATA_SIZE(op: PPyObject): Py_ssize_t; inline;
{ Возвращает максимальное значение символа. }
function PyUnicode_MAX_CHAR_VALUE(op: PPyObject): Py_UCS4; inline;

{ Читает символ по индексу. }
function PyUnicode_READ(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t): Py_UCS4; inline;
{ Читает символ из строки. }
function PyUnicode_READ_CHAR(unicode: PPyObject; index: Py_ssize_t): Py_UCS4; inline;
{ Записывает символ по индексу. }
procedure PyUnicode_WRITE(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t; Value: Py_UCS4); inline;

{ Проверяет, является ли символ суррогатом. }
function Py_UNICODE_IS_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ верхним суррогатом. }
function Py_UNICODE_IS_HIGH_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ нижним суррогатом. }
function Py_UNICODE_IS_LOW_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Объединяет суррогатную пару. }
function Py_UNICODE_JOIN_SURROGATES(high: Py_UCS4; low: Py_UCS4): Py_UCS4; inline;

{ Проверяет, является ли символ пробельным. }
function Py_UNICODE_ISSPACE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой в нижнем регистре. }
function Py_UNICODE_ISLOWER(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой в верхнем регистре. }
function Py_UNICODE_ISUPPER(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ "заголовочной" буквой. }
function Py_UNICODE_ISTITLE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ переносом строки. }
function Py_UNICODE_ISLINEBREAK(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ десятичной цифрой. }
function Py_UNICODE_ISDECIMAL(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ цифрой. }
function Py_UNICODE_ISDIGIT(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ числовым. }
function Py_UNICODE_ISNUMERIC(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ печатным. }
function Py_UNICODE_ISPRINTABLE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой. }
function Py_UNICODE_ISALPHA(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой или цифрой. }
function Py_UNICODE_ISALNUM(ch: Py_UCS4): cbool; inline;

{ Преобразует символ в нижний регистр. }
function Py_UNICODE_TOLOWER(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в верхний регистр. }
function Py_UNICODE_TOUPPER(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в "заголовочный" регистр. }
function Py_UNICODE_TOTITLE(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в его десятичное значение. }
function Py_UNICODE_TODECIMAL(ch: Py_UCS4): cint; inline;
{ Преобразует символ в его цифровое значение. }
function Py_UNICODE_TODIGIT(ch: Py_UCS4): cint; inline;
{ Преобразует символ в его числовое значение. }
function Py_UNICODE_TONUMERIC(ch: Py_UCS4): cdouble; inline;

implementation

function _PyASCIIObject_CAST(op: PPyObject): PPyASCIIObject;
begin
  Result := PPyASCIIObject(op);
end;

function _PyCompactUnicodeObject_CAST(op: PPyObject): PPyCompactUnicodeObject;
begin
  Result := PPyCompactUnicodeObject(op);
end;

function _PyUnicodeObject_CAST(op: PPyObject): PPyUnicodeObject;
begin
  Result := PPyUnicodeObject(op);
end;

function PyUnicode_Check(op: PPyObject): cbool;
begin
  Result := PyObject_TypeCheck(op, PyUnicode_Type);
end;

function PyUnicode_CheckExact(op: PPyObject): cbool;
begin
  Result := Py_IS_TYPE(op, PyUnicode_Type);
end;

function PyUnicode_CHECK_INTERNED(op: PPyObject): cbool;
begin
  {$IFDEF Py_GIL_DISABLED}
  Result := cbool(_Py_atomic_load_uint8_relaxed(_PyASCIIObject_CAST(op)^.state.interned));
  {$ELSE}
  Result := (_PyASCIIObject_CAST(op)^.state.flags and STATE_INTERNED_MASK) <> 0;
  {$ENDIF}
end;

function PyUnicode_IS_ASCII(op: PPyObject): cbool;
begin
  Result := (_PyASCIIObject_CAST(op)^.state.flags and STATE_ASCII_BIT) <> 0;
end;

function PyUnicode_IS_COMPACT(op: PPyObject): cbool;
begin
  Result := (_PyASCIIObject_CAST(op)^.state.flags and STATE_COMPACT_BIT) <> 0;
end;

function PyUnicode_IS_COMPACT_ASCII(op: PPyObject): cbool;
begin
  Result := (_PyASCIIObject_CAST(op)^.state.flags and (STATE_ASCII_BIT or STATE_COMPACT_BIT)) = (STATE_ASCII_BIT or STATE_COMPACT_BIT);
end;

function PyUnicode_KIND(op: PPyObject): PyUnicodeKind;
begin
  Result := PyUnicodeKind((_PyASCIIObject_CAST(op)^.state.flags and STATE_KIND_MASK) shr STATE_KIND_SHIFT);
end;

function PyUnicode_GET_LENGTH(op: PPyObject): Py_ssize_t;
begin
  Result := _PyASCIIObject_CAST(op)^.length;
end;

function PyUnicode_DATA(op: PPyObject): Pointer;
begin
  if PyUnicode_IS_COMPACT(op) then
  begin
    if PyUnicode_IS_ASCII(op) then
      Result := Pointer(PAnsiChar(op) + SizeOf(PyASCIIObject))
    else
      Result := Pointer(PAnsiChar(op) + SizeOf(PyCompactUnicodeObject));
  end
  else
    Result := _PyUnicodeObject_CAST(op)^.any;
end;

function PyUnicode_1BYTE_DATA(op: PPyObject): PPy_UCS1;
begin
  Result := PPy_UCS1(PyUnicode_DATA(op));
end;

function PyUnicode_2BYTE_DATA(op: PPyObject): PPy_UCS2;
begin
  Result := PPy_UCS2(PyUnicode_DATA(op));
end;

function PyUnicode_4BYTE_DATA(op: PPyObject): PPy_UCS4;
begin
  Result := PPy_UCS4(PyUnicode_DATA(op));
end;

function PyUnicode_GET_DATA_SIZE(op: PPyObject): Py_ssize_t;
begin
  Result := PyUnicode_GET_LENGTH(op) * Ord(PyUnicode_KIND(op));
end;

function PyUnicode_MAX_CHAR_VALUE(op: PPyObject): Py_UCS4;
begin
  if PyUnicode_IS_ASCII(op) then
    Result := $7F
  else
  case PyUnicode_KIND(op) of
    PyUnicode_1BYTE_KIND: Result := $FF;
    PyUnicode_2BYTE_KIND: Result := $FFFF;
    PyUnicode_4BYTE_KIND: Result := $10FFFF;
    else Result := 0;
  end;
end;

function PyUnicode_READ(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t): Py_UCS4;
begin
  case kind of
    PyUnicode_1BYTE_KIND: Result := PPy_UCS1(Data)[index];
    PyUnicode_2BYTE_KIND: Result := PPy_UCS2(Data)[index];
    PyUnicode_4BYTE_KIND: Result := PPy_UCS4(Data)[index];
    else Result := 0;
  end;
end;

function PyUnicode_READ_CHAR(unicode: PPyObject; index: Py_ssize_t): Py_UCS4;
begin
  Result := PyUnicode_READ(PyUnicode_KIND(unicode), PyUnicode_DATA(unicode), index);
end;

procedure PyUnicode_WRITE(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t; Value: Py_UCS4);
begin
  case kind of
    PyUnicode_1BYTE_KIND: PPy_UCS1(Data)[index] := Py_UCS1(Value);
    PyUnicode_2BYTE_KIND: PPy_UCS2(Data)[index] := Py_UCS2(Value);
    PyUnicode_4BYTE_KIND: PPy_UCS4(Data)[index] := Py_UCS4(Value);
  end;
end;

function Py_UNICODE_IS_SURROGATE(ch: Py_UCS4): cbool;
begin
  Result := (ch >= Py_UNICODE_SURROGATE_START) and (ch <= Py_UNICODE_SURROGATE_END);
end;

function Py_UNICODE_IS_HIGH_SURROGATE(ch: Py_UCS4): cbool;
begin
  Result := (ch >= Py_UNICODE_HIGH_SURROGATE_START) and (ch <= Py_UNICODE_HIGH_SURROGATE_END);
end;

function Py_UNICODE_IS_LOW_SURROGATE(ch: Py_UCS4): cbool;
begin
  Result := (ch >= Py_UNICODE_LOW_SURROGATE_START) and (ch <= Py_UNICODE_LOW_SURROGATE_END);
end;

function Py_UNICODE_JOIN_SURROGATES(high: Py_UCS4; low: Py_UCS4): Py_UCS4;
begin
  Result := $10000 + (((high and $03FF) shl 10) or (low and $03FF));
end;

var
  _PyUnicode_IsLowercase: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsUppercase: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsTitlecase: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsWhitespace: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsLinebreak: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_ToLowercase: function(ch: Py_UCS4): Py_UCS4; cdecl;
  _PyUnicode_ToUppercase: function(ch: Py_UCS4): Py_UCS4; cdecl;
  _PyUnicode_ToTitlecase: function(ch: Py_UCS4): Py_UCS4; cdecl;
  _PyUnicode_ToDecimalDigit: function(ch: Py_UCS4): cint; cdecl;
  _PyUnicode_ToDigit: function(ch: Py_UCS4): cint; cdecl;
  _PyUnicode_ToNumeric: function(ch: Py_UCS4): cdouble; cdecl;
  _PyUnicode_IsDecimalDigit: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsDigit: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsNumeric: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsPrintable: function(ch: Py_UCS4): cbool; cdecl;
  _PyUnicode_IsAlpha: function(ch: Py_UCS4): cbool; cdecl;

function Py_UNICODE_ISSPACE(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := (ch = 32) or ((ch >= 9) and (ch <= 13)) else Result := _PyUnicode_IsWhitespace(ch);
end;

function Py_UNICODE_ISLOWER(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := (ch >= Ord('a')) and (ch <= Ord('z')) else Result := _PyUnicode_IsLowercase(ch);
end;

function Py_UNICODE_ISUPPER(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := (ch >= Ord('A')) and (ch <= Ord('Z')) else Result := _PyUnicode_IsUppercase(ch);
end;

function Py_UNICODE_ISTITLE(ch: Py_UCS4): cbool;
begin
  Result := _PyUnicode_IsTitlecase(ch);
end;

function Py_UNICODE_ISLINEBREAK(ch: Py_UCS4): cbool;
begin
  Result := _PyUnicode_IsLinebreak(ch);
end;

function Py_UNICODE_ISDECIMAL(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := (ch >= Ord('0')) and (ch <= Ord('9')) else Result := _PyUnicode_IsDecimalDigit(ch);
end;

function Py_UNICODE_ISDIGIT(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := (ch >= Ord('0')) and (ch <= Ord('9')) else Result := _PyUnicode_IsDigit(ch);
end;

function Py_UNICODE_ISNUMERIC(ch: Py_UCS4): cbool;
begin
  Result := _PyUnicode_IsNumeric(ch);
end;

function Py_UNICODE_ISPRINTABLE(ch: Py_UCS4): cbool;
begin
  Result := _PyUnicode_IsPrintable(ch);
end;

function Py_UNICODE_ISALPHA(ch: Py_UCS4): cbool;
begin
  if ch < 128 then Result := ((ch >= Ord('a')) and (ch <= Ord('z'))) or ((ch >= Ord('A')) and (ch <= Ord('Z'))) else Result := _PyUnicode_IsAlpha(ch);
end;

function Py_UNICODE_ISALNUM(ch: Py_UCS4): cbool;
begin
  Result := Py_UNICODE_ISALPHA(ch) or Py_UNICODE_ISDECIMAL(ch) or Py_UNICODE_ISDIGIT(ch) or Py_UNICODE_ISNUMERIC(ch);
end;

function Py_UNICODE_TOLOWER(ch: Py_UCS4): Py_UCS4;
begin
  if (ch >= Ord('A')) and (ch <= Ord('Z')) then
    Result := ch + (Ord('a') - Ord('A'))
  else
    Result := _PyUnicode_ToLowercase(ch);
end;

function Py_UNICODE_TOUPPER(ch: Py_UCS4): Py_UCS4;
begin
  if (ch >= Ord('a')) and (ch <= Ord('z')) then
    Result := ch - (Ord('a') - Ord('A'))
  else
    Result := _PyUnicode_ToUppercase(ch);
end;

function Py_UNICODE_TOTITLE(ch: Py_UCS4): Py_UCS4;
begin
  Result := _PyUnicode_ToTitlecase(ch);
end;

function Py_UNICODE_TODECIMAL(ch: Py_UCS4): cint;
begin
  if ch < 128 then Result := ch - Ord('0') else Result := _PyUnicode_ToDecimalDigit(ch);
end;

function Py_UNICODE_TODIGIT(ch: Py_UCS4): cint;
begin
  if ch < 128 then Result := ch - Ord('0') else Result := _PyUnicode_ToDigit(ch);
end;

function Py_UNICODE_TONUMERIC(ch: Py_UCS4): cdouble;
begin
  if ch < 128 then Result := ch - Ord('0') else Result := _PyUnicode_ToNumeric(ch);
end;

initialization
  Pointer(PyUnicode_Type) := GetProc('PyUnicode_Type');
  Pointer(PyUnicodeIter_Type) := GetProc('PyUnicodeIter_Type');

  Pointer(PyUnicode_FromStringAndSize) := GetProc('PyUnicode_FromStringAndSize');
  Pointer(PyUnicode_FromString) := GetProc('PyUnicode_FromString');
  Pointer(PyUnicode_FromEncodedObject) := GetProc('PyUnicode_FromEncodedObject');
  Pointer(PyUnicode_FromObject) := GetProc('PyUnicode_FromObject');
  Pointer(PyUnicode_FromOrdinal) := GetProc('PyUnicode_FromOrdinal');
  Pointer(PyUnicode_New) := GetProc('PyUnicode_New');
  Pointer(PyUnicode_FromKindAndData) := GetProc('PyUnicode_FromKindAndData');

  Pointer(PyUnicode_FromFormat) := GetProc('PyUnicode_FromFormat');
  Pointer(PyUnicode_FromFormatV) := GetProc('PyUnicode_FromFormatV');
  Pointer(PyUnicode_InternInPlace) := GetProc('PyUnicode_InternInPlace');
  Pointer(PyUnicode_InternFromString) := GetProc('PyUnicode_InternFromString');

  {$IFNDEF PY_LIMITED_API}
  Pointer(PyUnicode_Substring) := GetProc('PyUnicode_Substring');
  Pointer(PyUnicode_GetLength) := GetProc('PyUnicode_GetLength');
  Pointer(PyUnicode_ReadChar) := GetProc('PyUnicode_ReadChar');
  Pointer(PyUnicode_WriteChar) := GetProc('PyUnicode_WriteChar');
  {$ENDIF}

  Pointer(PyUnicode_Resize) := GetProc('PyUnicode_Resize');

  Pointer(PyUnicode_GetDefaultEncoding) := GetProc('PyUnicode_GetDefaultEncoding');
  Pointer(PyUnicode_Decode) := GetProc('PyUnicode_Decode');
  Pointer(PyUnicode_AsEncodedString) := GetProc('PyUnicode_AsEncodedString');

  Pointer(PyUnicode_DecodeUTF8) := GetProc('PyUnicode_DecodeUTF8');
  Pointer(PyUnicode_DecodeUTF8Stateful) := GetProc('PyUnicode_DecodeUTF8Stateful');
  Pointer(PyUnicode_AsUTF8String) := GetProc('PyUnicode_AsUTF8String');
  {$IFNDEF PY_LIMITED_API}
  Pointer(PyUnicode_AsUTF8AndSize) := GetProc('PyUnicode_AsUTF8AndSize');
  {$ENDIF}

  Pointer(PyUnicode_Concat) := GetProc('PyUnicode_Concat');
  Pointer(PyUnicode_Append) := GetProc('PyUnicode_Append');
  Pointer(PyUnicode_AppendAndDel) := GetProc('PyUnicode_AppendAndDel');
  Pointer(PyUnicode_Find) := GetProc('PyUnicode_Find');
  {$IFNDEF PY_LIMITED_API}
  Pointer(PyUnicode_FindChar) := GetProc('PyUnicode_FindChar');
  {$ENDIF}
  Pointer(PyUnicode_Compare) := GetProc('PyUnicode_Compare');
  Pointer(PyUnicode_CompareWithASCIIString) := GetProc('PyUnicode_CompareWithASCIIString');

  Pointer(_PyUnicode_IsLowercase) := GetProc('_PyUnicode_IsLowercase');
  Pointer(_PyUnicode_IsUppercase) := GetProc('_PyUnicode_IsUppercase');
  Pointer(_PyUnicode_IsTitlecase) := GetProc('_PyUnicode_IsTitlecase');
  Pointer(_PyUnicode_IsWhitespace) := GetProc('_PyUnicode_IsWhitespace');
  Pointer(_PyUnicode_IsLinebreak) := GetProc('_PyUnicode_IsLinebreak');
  Pointer(_PyUnicode_ToLowercase) := GetProc('_PyUnicode_ToLowercase');
  Pointer(_PyUnicode_ToUppercase) := GetProc('_PyUnicode_ToUppercase');
  Pointer(_PyUnicode_ToTitlecase) := GetProc('_PyUnicode_ToTitlecase');
  Pointer(_PyUnicode_ToDecimalDigit) := GetProc('_PyUnicode_ToDecimalDigit');
  Pointer(_PyUnicode_ToDigit) := GetProc('_PyUnicode_ToDigit');
  Pointer(_PyUnicode_ToNumeric) := GetProc('_PyUnicode_ToNumeric');
  Pointer(_PyUnicode_IsDecimalDigit) := GetProc('_PyUnicode_IsDecimalDigit');
  Pointer(_PyUnicode_IsDigit) := GetProc('_PyUnicode_IsDigit');
  Pointer(_PyUnicode_IsNumeric) := GetProc('_PyUnicode_IsNumeric');
  Pointer(_PyUnicode_IsPrintable) := GetProc('_PyUnicode_IsPrintable');
  Pointer(_PyUnicode_IsAlpha) := GetProc('_PyUnicode_IsAlpha');
end.
