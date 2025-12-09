{$mode objfpc}
{$I config.inc}
unit py_pymem;

interface

uses
  ctypes, python;

{
  Модуль управления памятью Python C API.

  Предоставляет функции для выделения, перераспределения и освобождения
  памяти, управляемой интерпретатором Python. Разделен на два семейства:
  - `PyMem_*`: Требуют удержания GIL, интегрированы с отладчиком памяти Python.
  - `PyMem_Raw*`: Не требуют GIL, являются тонкой оберткой над системными
    `malloc`, `realloc`, `free`.

  Целевая версия Python: 3.14
}

// --- PyMem_* (GIL required) ---
var
  {
    Выделяет `size` байт памяти.
    При успехе возвращает указатель на выделенный блок, иначе `nil`.
    Требует удержания GIL.
  }
  PyMem_Malloc: function(size: csize_t): Pointer; cdecl;

  {
    Выделяет память для `nelem` элементов размером `elsize` каждый и обнуляет её.
    При успехе возвращает указатель на выделенный блок, иначе `nil`.
    Требует удержания GIL.
  }
  PyMem_Calloc: function(nelem, elsize: csize_t): Pointer; cdecl;

  {
    Изменяет размер блока памяти `ptr` на `new_size`.
    При успехе возвращает указатель на новый блок, иначе `nil`.
    Требует удержания GIL.
  }
  PyMem_Realloc: function(ptr: Pointer; new_size: csize_t): Pointer; cdecl;

  {
    Освобождает блок памяти `ptr`, ранее выделенный `PyMem_*`.
    Требует удержания GIL.
  }
  PyMem_Free: procedure(ptr: Pointer); cdecl;

{$IFNDEF PY_LIMITED_API}
// --- PyMem_Raw* (No GIL required) ---
  {
    Выделяет `size` байт памяти без удержания GIL.
  }
  PyMem_RawMalloc: function(size: csize_t): Pointer; cdecl;

  {
    Выделяет память для `nelem` элементов по `elsize` байт и обнуляет её, без удержания GIL.
  }
  PyMem_RawCalloc: function(nelem, elsize: csize_t): Pointer; cdecl;

  {
    Изменяет размер блока памяти `ptr` на `new_size` без удержания GIL.
  }
  PyMem_RawRealloc: function(ptr: Pointer; new_size: csize_t): Pointer; cdecl;

  {
    Освобождает блок памяти `ptr`, ранее выделенный `PyMem_Raw*`, без удержания GIL.
  }
  PyMem_RawFree: procedure(ptr: Pointer); cdecl;
{$ENDIF}

// --- Pascal Helpers (emulating C macros) ---
{
  Выделяет память для `n` элементов с размером `elt_size`.
  Аналог макроса `PyMem_New` в C. Вызывайте как: `PyMem_New(SizeOf(MyType), n)`.
}
function PyMem_New(elt_size: csize_t; n: Py_ssize_t): Pointer;

{
  Изменяет размер блока памяти `p` для хранения `n` элементов с размером `elt_size`.
  Аналог макроса `PyMem_Resize` в C. Вызывайте как: `PyMem_Resize(p, SizeOf(MyType), n)`.
}
function PyMem_Resize(p: Pointer; elt_size: csize_t; n: Py_ssize_t): Pointer;

implementation

function PyMem_New(elt_size: csize_t; n: Py_ssize_t): Pointer;
begin
  if (elt_size = 0) then
  begin
    Result := PyMem_Malloc(0);
    exit;
  end;
  if (n < 0) or (csize_t(n) > High(Py_ssize_t) div elt_size) then
    Exit(nil);
  Result := PyMem_Malloc(csize_t(n) * elt_size);
end;

function PyMem_Resize(p: Pointer; elt_size: csize_t; n: Py_ssize_t): Pointer;
begin
  if (elt_size = 0) then
  begin
    Result := PyMem_Realloc(p, 0);
    exit;
  end;
  if (n < 0) or (csize_t(n) > High(Py_ssize_t) div elt_size) then
    Exit(nil);
  Result := PyMem_Realloc(p, csize_t(n) * elt_size);
end;

initialization
  Pointer(PyMem_Malloc)  := GetProc('PyMem_Malloc');
  Pointer(PyMem_Calloc)  := GetProc('PyMem_Calloc');
  Pointer(PyMem_Realloc) := GetProc('PyMem_Realloc');
  Pointer(PyMem_Free)    := GetProc('PyMem_Free');

  {$IFNDEF PY_LIMITED_API}
  Pointer(PyMem_RawMalloc) := GetProc('PyMem_RawMalloc');
  Pointer(PyMem_RawCalloc) := GetProc('PyMem_RawCalloc');
  Pointer(PyMem_RawRealloc) := GetProc('PyMem_RawRealloc');
  Pointer(PyMem_RawFree) := GetProc('PyMem_RawFree');
  {$ENDIF}

finalization
end.
