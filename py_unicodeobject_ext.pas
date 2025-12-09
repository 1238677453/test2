{$mode fpc}
{$i config.inc}
unit py_unicodeobject_ext;

interface

uses
  ctypes, python
  {$IFDEF Py_GIL_DISABLED},
  py_atomic_ext
  {$ENDIF}
  ;

const
  { Состояния интернирования строк Unicode:
     SSTATE_NOT_INTERNED (0): строка не интернирована
     SSTATE_INTERNED_MORTAL (1): строка интернирована, но может быть удалена
     SSTATE_INTERNED_IMMORTAL (2): строка интернирована и бессмертна
     SSTATE_INTERNED_IMMORTAL_STATIC (3): строка интернирована, бессмертна и статична }
  SSTATE_NOT_INTERNED      = 0;
  SSTATE_INTERNED_MORTAL   = 1;
  SSTATE_INTERNED_IMMORTAL = 2;
  SSTATE_INTERNED_IMMORTAL_STATIC = 3;


  // Битовые маски и сдвиги для state.flags (соответствует C: bits 0..7 используются)
  STATE_INTERNED_MASK = $00000003; // bits 0..1
  STATE_KIND_MASK     = $0000001C; // bits 2..4
  STATE_KIND_SHIFT    = 2;
  STATE_COMPACT_BIT   = $00000020;  // bit 5
  STATE_ASCII_BIT     = $00000040;  // bit 6
  STATE_STATIC_BIT    = $00000080;  // bit 7


    { Диапазоны суррогатов в Unicode:
     Высокий суррогат: U+D800..U+DBFF
     Низкий суррогат: U+DC00..U+DFFF }
  Py_UNICODE_HIGH_SURROGATE_START = $D800;
  Py_UNICODE_HIGH_SURROGATE_END = $DBFF;
  Py_UNICODE_LOW_SURROGATE_START = $DC00;
  Py_UNICODE_LOW_SURROGATE_END = $DFFF;
  Py_UNICODE_SURROGATE_START = Py_UNICODE_HIGH_SURROGATE_START;
  Py_UNICODE_SURROGATE_END = Py_UNICODE_LOW_SURROGATE_END;


type
  { Возвращаемые значения функции PyUnicode_KIND(): *}
  PyUnicodeKind = (
    PyUnicode_1BYTE_KIND = 1,
    PyUnicode_2BYTE_KIND = 2,
    PyUnicode_4BYTE_KIND = 4
    );

  P_PyUnicodeObject_state = ^_PyUnicodeObject_state;

  { далее аналог _PyUnicode_IsUppercase через bitpacked record. Я не знаю что лучше

  _PyUnicodeObject_state = bitpacked record
    case byte of
      0: (
        {$IFDEF Py_GIL_DISABLED}
        interned: uint8_t; //8
        {$ELSE}
        { Если значение interned не равно нулю, две ссылки из
        словаря на этот объект не учитываются в ob_refcnt .
          Возможные значения здесь:
                 0: Not Interned
                 1: Interned
                 2: Interned and Immortal
                 3: Interned, Immortal, and Static
        Эта классификация позволяет среде выполнения определить правильный
        механизм очистки при завершении работы среды выполнения. }
        interned: 0..3; //2
        {$ENDIF}
       { Размер символа:

           - PyUnicode_1BYTE_KIND (1):

         * тип символа = Py_UCS1 (8 бит, без знака)
         * все символы находятся в диапазоне U+0000-U+00FF (latin1)
         * если установлен ascii, все символы находятся в диапазоне U+0000-U+007F
         (ASCII), в противном случае хотя бы один символ находится в диапазоне
         U+0080-U+00FF

          - PyUnicode_2BYTE_KIND (2):

         * тип символа = Py_UCS2 (16 бит, без знака)
         * все символы находятся в диапазоне U+0000-U+FFFF (BMP)
         * хотя бы один символ находится в диапазоне U+0100-U+FFFF

         - PyUnicode_4BYTE_KIND (4):

         * тип символа = Py_UCS4 (32 бита, без знака)
         * все символы находятся в диапазоне U+0000-U+10FFFF
         * по крайней мере, один символ находится в диапазоне U+10000-U+10FFFF}
        kind: 0..7; //3
       { Compact - это по отношению к схеме распределения. Компактные объекты unicode
       требуют только один блок памяти, в то время как некомпактные объекты используют
       один блок для структуры PyUnicodeObject и другой для буфера данных. }
        compact: 0..1; //1
       { Строка содержит только символы в диапазоне U+0000-U+007F (ASCII)
       и имеет вид PyUnicode_1BYTE_KIND. Если задан ascii и установлен параметр compact,
       используйте структуру PyASCIIObject. }
        ascii: 0..1; //1
        { Объект распределен статически. }
        statically_allocated: 0..1;); //1
      1: (padding1: cint;  //c-выравнивание  до 4 байт
        {$IFDEF Py_GIL_DISABLED}
        padding2: cint; //c-выравнивание до 8 байт
        {$ENDIF}
      );
  end;}

  _PyUnicodeObject_state = packed record
    {$IFDEF Py_GIL_DISABLED}
    // Сase Py_GIL_DISABLED: interned хранится отдельным байтом (атомарный доступ)
    interned: uint8_t;                 // unsigned char interned;
    _pad:     array[0..2] of byte;     // padding до границы 4 байт
    flags:    uint32_t;
    // остальные битовые поля (kind, compact, ascii, static)
    {$ELSE}
    // Normal case: все поля упакованы в 32-bit flags (эмуляция C bitfields)
    flags: uint32_t;
    // содержит interned (bits0..1), kind (bits2..4), compact (bit5), ascii (bit6), static (bit7)
    {$ENDIF}
  end;


  PPyASCIIObject = ^PyASCIIObject;
  { Строки только для ASCII, созданные с помощью PyUnicode_New, используют
   структуру PyASCIIObject. state.ascii и state.compact заданы, и данные
   сразу следуют за структурой. Значение utf8_length можно найти
   в поле length; указатель utf8 равен указателю данных. }
  PyASCIIObject  = record
            { Существует 3 формы строк в Юникоде:

         - compact ascii:

           * структура = PyASCIIObject
           * тест: PyUnicode_IS_COMPACT_ASCII(op)
           * kind = PyUnicode_1BYTE_KIND
           * compact = 1
           * ascii = 1
           * (length - это length utf8)
           * (данные начинаются сразу после структуры)
           * (поскольку ASCII декодируется из UTF-8, строка utf8 является данными)

         - compact:

           * структура = PyCompactUnicodeObject
           * тест: IsCompact(Op) and not IsAscii(Op)
           * вид = PyUnicode_1BYTE_KIND, PyUnicode_2BYTE_KIND или
            PyUnicode_4BYTE_KIND
           * compact = 1
           * ascii = 0
           * utf8 не используется совместно с данными
           * utf8_length = 0, если utf8 равно НУЛЮ
           * (данные начинаются сразу после структуры)

         - устаревшая строка:

           * structure = структура PyUnicodeObject
           * тест: not PyUnicode_IS_COMPACT(op)
           * вид = PyUnicode_1BYTE_KIND, PyUnicode_2BYTE_KIND или
            PyUnicode_4BYTE_KIND
           * компактный = 0
           * data.any не равно НУЛЮ
           * utf8 является общим и utf8_length = длина с данными.any, если ascii = 1
           * utf8_length = 0, если utf8 равно НУЛЮ

         Компактные строки используют только один блок памяти (структура + символы),
        тогда как устаревшие строки используют один блок для структуры и один блок
         для символов.

         Устаревшие строки создаются подклассами Unicode.

         Смотрите также _PyUnicode_CheckConsistency().
      }
    ob_base: PyObject;
    length:  Py_ssize_t; // Количество кодовых точек в строке
    hash:    Py_hash_t;  // Хэш -1, если не установлен
    state:   _PyUnicodeObject_state;
  end;


  PPyCompactUnicodeObject = ^PyCompactUnicodeObject;
  { Строки, отличные от ASCII, задаются через PyUnicode_New, и используют
   структуру PyCompactUnicodeObject.state.compact, и данные
   сразу следуют за структурой. }
  PyCompactUnicodeObject  = record
    _base: PyASCIIObject;
    { Количество байтов в utf8, исключая завершающий символ \\0. *}
    utf8_length: Py_ssize_t;
    { Представление в формате UTF-8 (завершается нулем) *}
    utf8:  PChar;
  end;

  PPyUnicodeObject = ^PyUnicodeObject;

  PyUnicodeObject = record
    base: PyCompactUnicodeObject;
      { Изначальный буфер Unicode  }
    case integer of
      0: (any: Pointer);
      1: (latin1: PPy_UCS1);
      2: (ucs2: PPy_UCS2);
      3: (ucs4: PPy_UCS4);
  end;


  // Макросы для приведения типов (Type Casting Macros)

{ Приведение указателя на PyObject к указателю на PyASCIIObject }
function _PyASCIIObject_CAST(op: PPyObject): PPyASCIIObject; inline;
{ Приведение указателя на PyObject к указателю на PyCompactUnicodeObject }
function _PyCompactUnicodeObject_CAST(op: PPyObject): PPyCompactUnicodeObject; inline;
{ Приведение указателя на PyObject к указателю на PyUnicodeObject }
function _PyUnicodeObject_CAST(op: PPyObject): PPyUnicodeObject; inline;

// Макросы для проверки типов строк (String Type Check Macros)

{ Возвращает ненулевое значение, если op интернирована, и ноль в противном случае.
   Аргумент str должен быть строкой; это не проверяется.
   Эта функция всегда завершается успешно.
   Детали реализации CPython: ненулевое возвращаемое значение может содержать
   дополнительную информацию о том, как интернирована строка.
   Смысл таких ненулевых значений, а также информация,
   связанная с интернированием каждой конкретной строки,
   может меняться в зависимости от версии CPython. }
function PyUnicode_CHECK_INTERNED(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка компактной ASCII строкой.
   Возвращает true, если state.compact и state.ascii установлены. }
function PyUnicode_IS_COMPACT_ASCII(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка компактной (не устаревшей).
   Возвращает true, если state.compact установлен. }
function PyUnicode_IS_COMPACT(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка ASCII строкой.
   Возвращает true, если state.ascii установлен. }
function PyUnicode_IS_ASCII(op: PPyObject): cbool; inline;
{ Проверяет, является ли строка компактной и ASCII одновременно.
   Эквивалентно PyUnicode_IS_COMPACT(op) and PyUnicode_IS_ASCII(op). }
function PyUnicode_IS_COMPACT_AND_ASCII(op: PPyObject): cbool; inline;

// Функции для получения данных (Data Access Macros)

{ Возвращает вид (kind) строки Unicode: 1, 2 или 4 байта на символ. }
function PyUnicode_KIND(op: PPyObject): PyUnicodeKind; inline;
{ Возвращает длину строки в кодовых точках. }
function PyUnicode_GET_LENGTH(op: PPyObject): Py_ssize_t; inline;
{ Возвращает кэшированный хэш или -1, если он еще не кэширован. }
function PyUnstable_Unicode_GET_CACHED_HASH(op: PPyObject): Py_hash_t; inline;
{ Возвращает указатель на начало данных строки Unicode.}
function PyUnicode_DATA(op: PPyObject): Pointer; inline;
{ Возвращает указатель на данные для строки с 1-байтовыми символами (Py_UCS1). }
function PyUnicode_1BYTE_DATA(op: PPyObject): PPy_UCS1; inline;
{ Возвращает указатель на данные для строки с 2-байтовыми символами (Py_UCS2). }
function PyUnicode_2BYTE_DATA(op: PPyObject): PPy_UCS2; inline;
{ Возвращает указатель на данные для строки с 4-байтовыми символами (Py_UCS4). }
function PyUnicode_4BYTE_DATA(op: PPyObject): PPy_UCS4; inline;
{ Возвращает размер данных строки в байтах. }
function PyUnicode_GET_DATA_SIZE(op: PPyObject): Py_ssize_t; inline;
{ Возвращает максимальное кодовое значение символа для строки. }
function PyUnicode_MAX_CHAR_VALUE(op: PPyObject): Py_UCS4; inline;

// Макросы для чтения и записи символов (Character Reading Macros)

{ Читает символ по индексу i из строки с указанным видом kind.
   kind должен быть PyUnicode_1BYTE_KIND, PyUnicode_2BYTE_KIND или PyUnicode_4BYTE_KIND. }
function PyUnicode_READ(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t): Py_UCS4; inline;
{ Читает символ по индексу i из строки, автоматически определяя вид. }
function PyUnicode_READ_CHAR(unicode: PPyObject; index: Py_ssize_t): Py_UCS4; inline;
{ Запиcь симвода в заданный индекс, начинающийся с нуля, в строке.
 Значения вида и указатель данных должны быть получены из строки с помощью
  PyUnicode_KIND() и PyUnicode_DATA() соответственно.
  Вы должны сохранить ссылку на эту строку при вызове PyUnicode_WRITE().
  Также применяются все требования PyUnicode_WriteChar(). }
procedure PyUnicode_WRITE(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t;
  Value: Py_UCS4); inline;


// Функции для работы с суррогатами (Surrogate Functions)

{ Проверяет, является ли символ суррогатом (высоким или низким).
   Суррогаты находятся в диапазоне U+D800..U+DFFF. }
function Py_UNICODE_IS_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ высоким суррогатом.
   Высокие суррогаты находятся в диапазоне U+D800..U+DBFF. }
function Py_UNICODE_IS_HIGH_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ низким суррогатом.
   Низкие суррогаты находятся в диапазоне U+DC00..U+DFFF. }
function Py_UNICODE_IS_LOW_SURROGATE(ch: Py_UCS4): cbool; inline;
{ Объединяет высокий и низкий суррогаты в одну кодовую точку.
   high должен быть высоким суррогатом, low - низким суррогатом.
   Возвращает кодовую точку в диапазоне U+10000..U+10FFFF. }
function Py_UNICODE_JOIN_SURROGATES(high: Py_UCS4; low: Py_UCS4): Py_UCS4; inline;
{ Извлекает высокий суррогат из кодовой точки.
   ch должна быть в диапазоне U+10000..U+10FFFF.
   Возвращает высокий суррогат в диапазоне U+D800..U+DBFF. }
function Py_UNICODE_HIGH_SURROGATE(ch: Py_UCS4): Py_UCS4; inline;
{ Извлекает низкий суррогат из кодовой точки.
   ch должна быть в диапазоне U+10000..U+10FFFF.
   Возвращает низкий суррогат в диапазоне U+DC00..U+DFFF. }
function Py_UNICODE_LOW_SURROGATE(ch: Py_UCS4): Py_UCS4; inline;

// Макросы для проверки свойств символов (Character Property Macros)

{ Проверяет, является ли символ пробельным.
   Использует _PyUnicode_IsWhitespace для не-ASCII символов. }
function Py_UNICODE_ISSPACE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ строчной буквой.}

function Py_UNICODE_ISLOWER(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ заглавной буквой.}
function Py_UNICODE_ISUPPER(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой в регистре titlecase.}

function Py_UNICODE_ISTITLE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ символом переноса строки.}
function Py_UNICODE_ISLINEBREAK(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ десятичной цифрой.}
function Py_UNICODE_ISDECIMAL(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ цифрой.}
function Py_UNICODE_ISDIGIT(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ числовым символом.}
function Py_UNICODE_ISNUMERIC(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ печатаемым.}
function Py_UNICODE_ISPRINTABLE(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой.}
function Py_UNICODE_ISALPHA(ch: Py_UCS4): cbool; inline;
{ Проверяет, является ли символ буквой или цифрой.
   Эквивалентно Py_UNICODE_ISALPHA(ch) or Py_UNICODE_ISDIGIT(ch). }
function Py_UNICODE_ISALNUM(ch: Py_UCS4): cbool; inline;

// Макросы для преобразования символов (Character Conversion Macros)

{ Преобразует символ в строчную букву.
   Использует _PyUnicode_ToLowercase. }
function Py_UNICODE_TOLOWER(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в заглавную букву.
   Использует _PyUnicode_ToUppercase. }
function Py_UNICODE_TOUPPER(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в букву в регистре titlecase.
   Использует _PyUnicode_ToTitlecase. }
function Py_UNICODE_TOTITLE(ch: Py_UCS4): Py_UCS4; inline;
{ Преобразует символ в десятичную цифру.
   Использует _PyUnicode_ToDecimalDigit. Возвращает -1, если символ не является десятичной цифрой. }
function Py_UNICODE_TODECIMAL(ch: Py_UCS4): cint; inline;
{ Преобразует символ в цифру.
   Использует _PyUnicode_ToDigit. Возвращает -1, если символ не является цифрой. }
function Py_UNICODE_TODIGIT(ch: Py_UCS4): cint; inline;
{ Преобразует символ в числовое значение.
   Использует _PyUnicode_ToNumeric. Возвращает -1.0, если символ не является числовым. }
function Py_UNICODE_TONUMERIC(ch: Py_UCS4): cdouble; inline;

var

  { Статические функции }

{ Создаёт новый объект Unicode.
   Параметр maxchar должен указывать истинную максимальную кодовую точку,
   которая будет размещена в строке. В качестве приближения его можно округлить
   до ближайшего значения из последовательности: 127, 255, 65535, 1114111.
   В случае ошибки устанавливает исключение и возвращает NULL.
   После создания строку можно заполнить с помощью функций PyUnicode_WriteChar(),
   PyUnicode_CopyCharacters(), PyUnicode_Fill(), PyUnicode_WRITE() или аналогичных.
   Поскольку строки считаются неизменяемыми, следите за тем, чтобы не «использовать»
   результат в процессе его модификации. В частности, до того как строка будет
   заполнена окончательным содержимым, с ней **нельзя**:
   - вычислять хеш-сумму;
   - преобразовывать в UTF-8 или другое не-«каноническое» представление;
   - изменять счётчик ссылок;
   - передавать другим фрагментам кода, которые могут выполнить одно из
     вышеперечисленных действий.
   Этот список не является исчерпывающим.
   Ответственность за соблюдение этих ограничений лежит на вас;
   Python не всегда проверяет выполнение данных требований.
  Чтобы случайно не раскрыть частично заполненный строковый объект,
  предпочтительно использовать одну из функций PyUnicode_From*.}
  PyUnicode_New: function(size: Py_ssize_t; maxchar: Py_UCS4): PPyObject; cdecl;
{ Скопировать символы из одного юникод-объекта в другой. Эта функция выполняет
   преобразование символов, если это необходимо, и прибегает к использованию
   `memcpy()`, если это возможно. Возвращает -1 и устанавливает исключение
   в случае ошибки, иначе возвращает количество скопированных символов.
   Строка не должна была быть ещё «использованной».
   См. подробности в описании функции `PyUnicode_New()`.
   Примечание: эта функция не записывает завершающий нулевой символ.}
  PyUnicode_CopyCharacters: function(to_: PPyObject; to_start: Py_ssize_t;
  from_: PPyObject; from_start, how_many: Py_ssize_t): Py_ssize_t; cdecl;
{ Заполнить строку символом: записать символ `fill_char` в диапазон
  `[start : start + length]` строки Unicode. Возвращает ошибку, если символ
  `fill_char` превосходит максимальный символ строки или если строка имеет
   более одной ссылки. Строка не должна быть ещё «использована».
   Подробности смотрите в документации функции `PyUnicode_New()`.
  Возвращает количество записанных символов или -1 с возникновением исключения
  в случае ошибки. }
  PyUnicode_Fill: function(unicode: PPyObject; start, length: Py_ssize_t;
  fill_char: Py_UCS4): Py_ssize_t; cdecl;
{ Создать новый объект Unicode с указанным типом (`kind`,
   возможные значения включают `PyUnicode_1BYTE_KIND` и другие,
   как возвращённые функцией `PyUnicode_KIND()`).
   Буфер должен указывать на массив размером, соответствующим количеству
   единиц в 1, 2 или 4 байта на символ, как задано видом (`kind`).
   Если необходимо, входной буфер копируется и преобразуется в
   каноническое представление.
   Например, если буфер является строкой UCS4 (`PyUnicode_4BYTE_KIND`)
   и состоит только из кодовых точек в диапазоне UCS1, он будет преобразован
   в UCS1 (`PyUnicode_1BYTE_KIND`). }
  PyUnicode_FromKindAndData: function(kind: PyUnicodeKind; const buffer: Pointer;
  size: Py_ssize_t): PPyObject; cdecl;
{ Возвращает интернированный объект Unicode в качестве идентификатора;
 может произойти сбой, если его нет в памяти }
  _PyUnicode_FromId: function(Id: PPy_Identifier): PPyObject; cdecl;


implementation

var

  { Статические функции }

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


// Реализация макросов приведения типов
function _PyASCIIObject_CAST(op: PPyObject): PPyASCIIObject; inline;
begin
  Result := PPyASCIIObject(op);
end;

function _PyCompactUnicodeObject_CAST(op: PPyObject): PPyCompactUnicodeObject; inline;
begin
  Result := PPyCompactUnicodeObject(op);
end;

function _PyUnicodeObject_CAST(op: PPyObject): PPyUnicodeObject; inline;
begin
  Result := PPyUnicodeObject(op);
end;

// Реализация макросов проверки типов строк

function PyUnicode_CHECK_INTERNED(op: PPyObject): cbool; inline;
begin
  {$IFDEF Py_GIL_DISABLED}
  // атомарное чтение отдельного байта interned
  Result := cbool(_Py_atomic_load_uint8_relaxed(_PyASCIIObject_CAST(op)^.state.interned));
  {$ELSE}
  Result := (_PyASCIIObject_CAST(op)^.state.flags and STATE_INTERNED_MASK) <> 0;
  {$ENDIF}
end;

function PyUnicode_IS_ASCII(op: PPyObject): cbool; inline;
begin
  Result := (PPyUnicodeObject(op)^.base._base.state.flags and STATE_ASCII_BIT) <> 0;
end;


function PyUnicode_IS_COMPACT(op: PPyObject): cbool; inline;
begin
  Result := (_PyASCIIObject_CAST(op)^.state.flags and STATE_COMPACT_BIT) <> 0;
end;

function PyUnicode_IS_COMPACT_ASCII(op: PPyObject): cbool; inline;
begin
  Result := PyUnicode_IS_COMPACT(op) and PyUnicode_IS_ASCII(op);
end;

function PyUnicode_IS_COMPACT_AND_ASCII(op: PPyObject): cbool; inline;
begin
  Result := PyUnicode_IS_COMPACT_ASCII(op);
end;

// Реализация макросов получения данных

function PyUnicode_KIND(op: PPyObject): PyUnicodeKind; inline;
begin
  Result := PyUnicodeKind((PPyUnicodeObject(op)^.base._base.state.flags and
    STATE_KIND_MASK) shr STATE_KIND_SHIFT);
end;

function PyUnicode_GET_LENGTH(op: PPyObject): Py_ssize_t; inline;
begin
  Result := PPyUnicodeObject(op)^.base._base.length;
end;

function PyUnstable_Unicode_GET_CACHED_HASH(op: PPyObject): Py_hash_t; inline;
begin
  {$IFDEF Py_GIL_DISABLED}
  Result := _Py_atomic_load_uint8_relaxed((_PyASCIIObject_CAST(op)^.hash));
  {$ELSE}
  Result := _PyASCIIObject_CAST(op)^.hash;
  {$ENDIF}
end;

function PyUnicode_DATA(op: PPyObject): Pointer; inline;
begin
  if PyUnicode_IS_COMPACT_ASCII(op) then
    // compact ascii: данные сразу после PyASCIIObject
    Result := Pointer(pbyte(@(_PyASCIIObject_CAST(op)^.ob_base)) + SizeOf(PyASCIIObject))
  else if PyUnicode_IS_COMPACT(op) then
    // compact non-ascii: данные сразу после PyCompactUnicodeObject
    Result := Pointer(pbyte(@(_PyCompactUnicodeObject_CAST(op)^._base)) +
      SizeOf(PyCompactUnicodeObject))
  else
    // legacy string
    Result := PPyUnicodeObject(op)^.any;
end;

function PyUnicode_1BYTE_DATA(op: PPyObject): PPy_UCS1; inline;
begin
  Result := PPy_UCS1(PyUnicode_DATA(op));
end;

function PyUnicode_2BYTE_DATA(op: PPyObject): PPy_UCS2; inline;
begin
  Result := PPy_UCS2(PyUnicode_DATA(op));
end;

function PyUnicode_4BYTE_DATA(op: PPyObject): PPy_UCS4; inline;
begin
  Result := PPy_UCS4(PyUnicode_DATA(op));
end;

function PyUnicode_GET_DATA_SIZE(op: PPyObject): Py_ssize_t; inline;
begin
  case PyUnicode_KIND(op) of
    PyUnicode_1BYTE_KIND: Result := PyUnicode_GET_LENGTH(op) * SizeOf(Py_UCS1);
    PyUnicode_2BYTE_KIND: Result := PyUnicode_GET_LENGTH(op) * SizeOf(Py_UCS2);
    PyUnicode_4BYTE_KIND: Result := PyUnicode_GET_LENGTH(op) * SizeOf(Py_UCS4);
    else
      Result := 0;
  end;
end;

function PyUnicode_MAX_CHAR_VALUE(op: PPyObject): Py_UCS4; inline;
begin
  case PyUnicode_KIND(op) of
    PyUnicode_1BYTE_KIND: Result := $FF;
    PyUnicode_2BYTE_KIND: Result := $FFFF;
    PyUnicode_4BYTE_KIND: Result := $10FFFF;
    else
      Result := 0;
  end;
end;

// Реализация макросов чтения символов
function PyUnicode_READ(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t): Py_UCS4; inline;
begin
  assert(index >= 0);
  case kind of
    PyUnicode_1BYTE_KIND: Result := PPy_UCS1(Data)[index];
    PyUnicode_2BYTE_KIND: Result := PPy_UCS2(Data)[index];
    PyUnicode_4BYTE_KIND: Result := PPy_UCS4(Data)[index];
    else
      Result := 0;
  end;
end;

function PyUnicode_READ_CHAR(unicode: PPyObject; index: Py_ssize_t): Py_UCS4; inline;
begin
  assert(index >= 0);
  // Допускает чтение символа NUL из str[len(str)]
  assert(index <= PyUnicode_GET_LENGTH(unicode));
  Result := PyUnicode_READ(PyUnicode_KIND(unicode), PyUnicode_DATA(unicode), index);
end;


procedure PyUnicode_WRITE(kind: PyUnicodeKind; Data: Pointer; index: Py_ssize_t;
  Value: Py_UCS4); inline;
begin
  assert(index >= 0);
  case kind of
    PyUnicode_1BYTE_KIND: PPy_UCS1(Data)[index] := Py_UCS1(Value);
    PyUnicode_2BYTE_KIND: PPy_UCS2(Data)[index] := Py_UCS2(Value);
    PyUnicode_4BYTE_KIND: PPy_UCS4(Data)[index] := Py_UCS4(Value);
    else
      assert(2 = 1);
  end;
end;


// Реализация функций для работы с суррогатами
function Py_UNICODE_IS_SURROGATE(ch: Py_UCS4): cbool; inline;
begin
  Result := (ch >= Py_UNICODE_SURROGATE_START) and (ch <= Py_UNICODE_SURROGATE_END);
end;

function Py_UNICODE_IS_HIGH_SURROGATE(ch: Py_UCS4): cbool; inline;
begin
  Result := (ch >= Py_UNICODE_HIGH_SURROGATE_START) and (ch <= Py_UNICODE_HIGH_SURROGATE_END);
end;

function Py_UNICODE_IS_LOW_SURROGATE(ch: Py_UCS4): cbool; inline;
begin
  Result := (ch >= Py_UNICODE_LOW_SURROGATE_START) and (ch <= Py_UNICODE_LOW_SURROGATE_END);
end;

function Py_UNICODE_JOIN_SURROGATES(high: Py_UCS4; low: Py_UCS4): Py_UCS4; inline;
begin
  assert(Py_UNICODE_IS_HIGH_SURROGATE(high));
  assert(Py_UNICODE_IS_LOW_SURROGATE(low));
  // Объединение суррогатов: ((high - 0xD800) << 10) + (low - 0xDC00) + 0x10000
  Result := ((high - Py_UNICODE_HIGH_SURROGATE_START) shl 10) +
    (low - Py_UNICODE_LOW_SURROGATE_START) + $10000;
end;

function Py_UNICODE_HIGH_SURROGATE(ch: Py_UCS4): Py_UCS4; inline;
begin
  assert(($10000 <= ch) and (ch <= $10FFFF));
  // Извлечение высокого суррогата: ((ch - 0x10000) >> 10) + 0xD800
  Result := ((ch - $10000) shr 10) + Py_UNICODE_HIGH_SURROGATE_START;
end;

function Py_UNICODE_LOW_SURROGATE(ch: Py_UCS4): Py_UCS4; inline;
begin
  assert(($10000 <= ch) and (ch <= $10FFFF));
  // Извлечение низкого суррогата: ((ch - 0x10000) & 0x3FF) + 0xDC00
  Result := ((ch - $10000) and $3FF) + Py_UNICODE_LOW_SURROGATE_START;
end;

// Реализация макросов проверки свойств символов
function Py_UNICODE_ISSPACE(ch: Py_UCS4): cbool; inline;
begin
  // Для ASCII символов используем быструю проверку
  if ch <= $7F then
    Result := ch in [$20, $09..$0D]
  // пробел, табуляция, перевод строки и т.д.
  else
    Result := _PyUnicode_IsWhitespace(ch);
end;

function Py_UNICODE_ISLOWER(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('a')..Ord('z')]
  else
    Result := _PyUnicode_IsLowercase(ch);
end;

function Py_UNICODE_ISUPPER(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('A')..Ord('Z')]
  else
    Result := _PyUnicode_IsUppercase(ch);
end;

function Py_UNICODE_ISTITLE(ch: Py_UCS4): cbool; inline;
begin
  Result := _PyUnicode_IsTitlecase(ch);
end;

function Py_UNICODE_ISLINEBREAK(ch: Py_UCS4): cbool; inline;
begin
  Result := _PyUnicode_IsLinebreak(ch);
end;

function Py_UNICODE_ISDECIMAL(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('0')..Ord('9')]
  else
    Result := _PyUnicode_IsDecimalDigit(ch);
end;

function Py_UNICODE_ISDIGIT(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('0')..Ord('9')]
  else
    Result := _PyUnicode_IsDigit(ch);
end;

function Py_UNICODE_ISNUMERIC(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('0')..Ord('9')]
  else
    Result := _PyUnicode_IsNumeric(ch);
end;

function Py_UNICODE_ISPRINTABLE(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    // ASCII печатаемые символы: от 0x20 (пробел) до 0x7E (~)
    Result := ch in [$20..$7E]
  else
    Result := _PyUnicode_IsPrintable(ch);
end;

function Py_UNICODE_ISALPHA(ch: Py_UCS4): cbool; inline;
begin
  if ch <= $7F then
    Result := ch in [Ord('a')..Ord('z'), Ord('A')..Ord('Z')]
  else
    Result := _PyUnicode_IsAlpha(ch);
end;

function Py_UNICODE_ISALNUM(ch: Py_UCS4): cbool; inline;
begin
  Result := Py_UNICODE_ISALPHA(ch) or Py_UNICODE_ISDIGIT(ch);
end;

// Реализация макросов преобразования символов
function Py_UNICODE_TOLOWER(ch: Py_UCS4): Py_UCS4; inline;
begin
  if ch <= $7F then
  begin
    if ch in [Ord('A')..Ord('Z')] then
      Result := ch + (Ord('a') - Ord('A'))
    else
      Result := ch;
  end
  else
    Result := _PyUnicode_ToLowercase(ch);
end;

function Py_UNICODE_TOUPPER(ch: Py_UCS4): Py_UCS4; inline;
begin
  if ch <= $7F then
  begin
    if ch in [Ord('a')..Ord('z')] then
      Result := ch - (Ord('a') - Ord('A'))
    else
      Result := ch;
  end
  else
    Result := _PyUnicode_ToUppercase(ch);
end;

function Py_UNICODE_TOTITLE(ch: Py_UCS4): Py_UCS4; inline;
begin
  Result := _PyUnicode_ToTitlecase(ch);
end;

function Py_UNICODE_TODECIMAL(ch: Py_UCS4): cint; inline;
begin
  if ch <= $7F then
  begin
    if ch in [Ord('0')..Ord('9')] then
      Result := ch - Ord('0')
    else
      Result := -1;
  end
  else
    Result := _PyUnicode_ToDecimalDigit(ch);
end;

function Py_UNICODE_TODIGIT(ch: Py_UCS4): cint; inline;
begin
  if ch <= $7F then
  begin
    if ch in [Ord('0')..Ord('9')] then
      Result := ch - Ord('0')
    else
      Result := -1;
  end
  else
    Result := _PyUnicode_ToDigit(ch);
end;

function Py_UNICODE_TONUMERIC(ch: Py_UCS4): cdouble; inline;
begin
  if ch <= $7F then
  begin
    if ch in [Ord('0')..Ord('9')] then
      Result := ch - Ord('0')
    else
      Result := -1.0;
  end
  else
    Result := _PyUnicode_ToNumeric(ch);
end;


initialization

  // Инициализация внешних функций

  Pointer(PyUnicode_New)      := getProc('PyUnicode_New');
  Pointer(PyUnicode_CopyCharacters) := getProc('PyUnicode_CopyCharacters');
  Pointer(PyUnicode_Fill)     := getProc('PyUnicode_Fill');
  Pointer(PyUnicode_FromKindAndData) := getProc('PyUnicode_FromKindAndData');
  Pointer(_PyUnicode_FromId)  := getProc('_PyUnicode_FromId');
  Pointer(_PyUnicode_IsLowercase) := getProc('_PyUnicode_IsLowercase');
  Pointer(_PyUnicode_IsUppercase) := getProc('_PyUnicode_IsUppercase');
  Pointer(_PyUnicode_IsTitlecase) := getProc('_PyUnicode_IsTitlecase');
  Pointer(_PyUnicode_IsWhitespace) := getProc('_PyUnicode_IsWhitespace');
  Pointer(_PyUnicode_IsLinebreak) := getProc('_PyUnicode_IsLinebreak');
  Pointer(_PyUnicode_ToLowercase) := getProc('_PyUnicode_ToLowercase');
  Pointer(_PyUnicode_ToUppercase) := getProc('_PyUnicode_ToUppercase');
  Pointer(_PyUnicode_ToTitlecase) := getProc('_PyUnicode_ToTitlecase');
  Pointer(_PyUnicode_ToDecimalDigit) := getProc('_PyUnicode_ToDecimalDigit');
  Pointer(_PyUnicode_ToDigit) := getProc('_PyUnicode_ToDigit');
  Pointer(_PyUnicode_ToNumeric) := getProc('_PyUnicode_ToNumeric');
  Pointer(_PyUnicode_IsDecimalDigit) := getProc('_PyUnicode_IsDecimalDigit');
  Pointer(_PyUnicode_IsDigit) := getProc('_PyUnicode_IsDigit');
  Pointer(_PyUnicode_IsNumeric) := getProc('_PyUnicode_IsNumeric');
  Pointer(_PyUnicode_IsPrintable) := getProc('_PyUnicode_IsPrintable');
  Pointer(_PyUnicode_IsAlpha) := getProc('_PyUnicode_IsAlpha');
end.
