{$mode objfpc}
{$I config.inc}
{
  Модуль для кроссплатформенных атомарных операций.

  Предоставляет функции для выполнения атомарных операций, необходимых
  для сборок Python без GIL.

  Целевая версия Python: 3.14
}
unit py_atomic_ext;

interface

uses
  ctypes, python;

var
  // --- Load ---
  _Py_atomic_load_uint8_relaxed: function(addr: Puint8_t): uint8_t; cdecl;
  _Py_atomic_load_uintptr_relaxed: function(addr: puintptr_t): uintptr_t; cdecl;
  _Py_atomic_load_ssize_relaxed: function(addr: PPy_ssize_t): Py_ssize_t; cdecl;

  // --- Store ---
  _Py_atomic_store_uint8_relaxed: procedure(addr: Puint8_t; v: uint8_t); cdecl;
  _Py_atomic_store_uintptr_relaxed: procedure(addr: puintptr_t; v: uintptr_t); cdecl;
  _Py_atomic_store_ssize_relaxed: procedure(addr: PPy_ssize_t; v: Py_ssize_t); cdecl;

  // --- Exchange ---
  _Py_atomic_exchange_uint8_relaxed: function(addr: Puint8_t; v: uint8_t): uint8_t; cdecl;
  _Py_atomic_exchange_uintptr_relaxed: function(addr: puintptr_t; v: uintptr_t): uintptr_t; cdecl;

  // --- Compare Exchange ---
  _Py_atomic_compare_exchange_uint8_relaxed: function(addr: Puint8_t; expected: Puint8_t; desired: uint8_t): cbool; cdecl;
  _Py_atomic_compare_exchange_uintptr_relaxed: function(addr: puintptr_t; expected: puintptr_t; desired: uintptr_t): cbool; cdecl;

implementation

initialization
  Pointer(_Py_atomic_load_uint8_relaxed) := GetProc('_Py_atomic_load_uint8_relaxed');
  Pointer(_Py_atomic_load_uintptr_relaxed) := GetProc('_Py_atomic_load_uintptr_relaxed');
  Pointer(_Py_atomic_load_ssize_relaxed) := GetProc('_Py_atomic_load_ssize_relaxed');

  Pointer(_Py_atomic_store_uint8_relaxed) := GetProc('_Py_atomic_store_uint8_relaxed');
  Pointer(_Py_atomic_store_uintptr_relaxed) := GetProc('_Py_atomic_store_uintptr_relaxed');
  Pointer(_Py_atomic_store_ssize_relaxed) := GetProc('_Py_atomic_store_ssize_relaxed');

  Pointer(_Py_atomic_exchange_uint8_relaxed) := GetProc('_Py_atomic_exchange_uint8_relaxed');
  Pointer(_Py_atomic_exchange_uintptr_relaxed) := GetProc('_Py_atomic_exchange_uintptr_relaxed');

  Pointer(_Py_atomic_compare_exchange_uint8_relaxed) := GetProc('_Py_atomic_compare_exchange_uint8_relaxed');
  Pointer(_Py_atomic_compare_exchange_uintptr_relaxed) := GetProc('_Py_atomic_compare_exchange_uintptr_relaxed');
end.
