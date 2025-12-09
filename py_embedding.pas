{$I config.inc}
{
  Модуль для встраивания интерпретатора Python в приложения.

  Предоставляет функции для инициализации, завершения работы и выполнения
  кода в интерпретаторе Python из другого приложения.

  Целевая версия Python: 3.14
}
unit py_embedding;

interface

uses
  ctypes, python;

var
  // --- Initialization and Finalization ---
  { Инициализирует интерпретатор Python. }
  Py_Initialize: procedure; cdecl;
  { Инициализирует интерпретатор с расширенной конфигурацией. }
  Py_InitializeEx: procedure(initsigs: cint); cdecl;
  { Завершает работу интерпретатора. }
  Py_FinalizeEx: function: cint; cdecl;
  { Проверяет, был ли инициализирован интерпретатор. }
  Py_IsInitialized: function: cint; cdecl;

  // --- Running Code ---
  { Выполняет строку кода в главном модуле. }
  PyRun_SimpleString: function(command: pansichar): cint; cdecl;
  { Выполняет строку кода с указанием глобального и локального словарей. }
  PyRun_String: function(str: pansichar; start: cint; globals, locals: PPyObject): PPyObject; cdecl;

  // --- Program and Home Directory ---
  { Устанавливает имя программы. }
  Py_SetProgramName: procedure(name: PWideChar); cdecl;
  { Возвращает имя программы. }
  Py_GetProgramName: function: PWideChar; cdecl;
  { Устанавливает "домашний" каталог Python. }
  Py_SetPythonHome: procedure(home: PWideChar); cdecl;
  { Возвращает "домашний" каталог Python. }
  Py_GetPythonHome: function: PWideChar; cdecl;

implementation

initialization
  Pointer(Py_Initialize) := GetProc('Py_Initialize');
  Pointer(Py_InitializeEx) := GetProc('Py_InitializeEx');
  Pointer(Py_FinalizeEx) := GetProc('Py_FinalizeEx');
  Pointer(Py_IsInitialized) := GetProc('Py_IsInitialized');

  Pointer(PyRun_SimpleString) := GetProc('PyRun_SimpleString');
  Pointer(PyRun_String) := GetProc('PyRun_String');

  Pointer(Py_SetProgramName) := GetProc('Py_SetProgramName');
  Pointer(Py_GetProgramName) := GetProc('Py_GetProgramName');
  Pointer(Py_SetPythonHome) := GetProc('Py_SetPythonHome');
  Pointer(Py_GetPythonHome) := GetProc('Py_GetPythonHome');
end.
