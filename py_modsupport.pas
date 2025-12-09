{$mode fpc}
{$i config.inc}
{
  Модуль для создания и управления модулями Python.

  Предоставляет функции для определения, создания и модификации модулей,
  а также для парсинга аргументов и создания Python-объектов.

  Целевая версия Python: 3.14
}
unit py_modsupport;

interface

uses
  ctypes, python;

const
  // --- Module Definition Slots ---
  Py_mod_create = 1;
  Py_mod_exec   = 2;
  Py_mod_multiple_interpreters = 3;
  {$IFDEF Py_GIL_DISABLED}
  Py_mod_gil = 4;
  Py_MOD_GIL_USED = Pointer(0);
  Py_MOD_GIL_NOT_USED = Pointer(1);
  {$ENDIF}

  {$IFNDEF PY_LIMITED_API}
  // --- PyABIInfo Flags ---
  PyABIInfo_STABLE   = $0001;
  PyABIInfo_GIL      = $0002;
  PyABIInfo_FREETHREADED = $0004;
  PyABIInfo_INTERNAL = $0008;
  {$ENDIF}

type
  { Базовая структура для определения модуля. }
  PPyModuleDef_Base = ^PyModuleDef_Base;
  PyModuleDef_Base = record
    ob_base: PyObject;
    m_init:  function(): PPyObject; cdecl;
    m_index: Py_ssize_t;
    m_copy:  PPyObject;
  end;

  { Определяет слот в `PyModuleDef`. }
  PPyModuleDef_Slot = ^PyModuleDef_Slot;
  PyModuleDef_Slot  = record
    slot:  cint;
    Value: Pointer;
  end;

  { Основная структура для определения модуля. }
  PPyModuleDef = ^PyModuleDef;
  PyModuleDef  = record
    m_base:     PyModuleDef_Base;
    m_name:     pansichar;
    m_doc:      pansichar;
    m_size:     Py_ssize_t;
    m_methods:  PPyMethodDef;
    m_slots:    PPyModuleDef_Slot;
    m_traverse: traverseproc;
    m_clear:    inquiry;
    m_free:     pydestructor;
  end;

  {$IFNDEF PY_LIMITED_API}
  { Структура с информацией об ABI. }
  PyABIInfo = record
    abiinfo_major_version: cuint8;
    abiinfo_minor_version: cuint8;
    flags: cuint16;
    build_version: cuint32;
    abi_version: cuint32;
  end;
  PPyABIInfo = ^PyABIInfo;
  {$ENDIF}

var
  // --- API Functions ---
  { Указатель на тип `PyModuleDef`. }
  PyModuleDef_Type: PPyTypeObject;

  {$IFNDEF PY_LIMITED_API}
  { Проверяет совместимость ABI. }
  PyABIInfo_Check: function(info: PPyABIInfo; module_name: pansichar): cint; cdecl;
  {$ENDIF}

  { Создаёт модуль на основе `PyModuleDef`. }
  PyModule_Create2: function(Module: PPyModuleDef; module_api_version: cint): PPyObject; cdecl;
  { Добавляет объект в модуль (ворует ссылку при успехе). }
  PyModule_AddObject: function(Module: PPyObject; Name: pansichar; Value: PPyObject): cint; cdecl;
  { Добавляет целочисленную константу в модуль. }
  PyModule_AddIntConstant: function(Module: PPyObject; Name: pansichar; AValue: clong): cint; cdecl;
  { Добавляет строковую константу в модуль. }
  PyModule_AddStringConstant: function(Module: PPyObject; Name, Value: pansichar): cint; cdecl;
  { Создаёт объект `CFunction`. }
  PyCFunction_NewEx: function(ml: PPyMethodDef; Self: PPyObject; Module: PPyObject): PPyObject; cdecl;

  {$IFNDEF PY_LIMITED_API}
  { Добавляет функции из `PyMethodDef` в модуль. }
  PyModule_AddFunctions: function(Obj: PPyObject; MethodDef: PPyMethodDef): cint; cdecl;
  { Создаёт объект `CMethod`. }
  PyCMethod_New: function(ml: PPyMethodDef; Self: PPyObject; Module: PPyObject; cls: PPyTypeObject): PPyObject; cdecl;
  { Создаёт новый, пустой модуль. }
  PyModule_New: function(key: pansichar): PPyObject; cdecl;
  { Создаёт модуль из `PyModuleDef` и `spec`. }
  PyModule_FromDefAndSpec2: function(def: PPyModuleDef; spec: PPyObject; module_api_version: cint): PPyObject; cdecl;
  { Выполняет код модуля. }
  PyModule_ExecDef: function(Module: PPyObject; moduledef: PPyModuleDef): cint; cdecl;
  { Добавляет объект в модуль (не ворует ссылку). }
  PyModule_AddObjectRef: function(Module: PPyObject; const Name: pansichar; Value: PPyObject): cint; cdecl;
  { Добавляет объект в модуль (ворует ссылку). }
  PyModule_Add: function(Module: PPyObject; Name: pansichar; Value: PPyObject): cint; cdecl;
  { Устанавливает строку документации модуля. }
  PyModule_SetDocString: function(Module: PPyObject; doc: pansichar): cint; cdecl;
  { Добавляет тип в модуль. }
  PyModule_AddType: function(Module: PPyObject; type_: PPyTypeObject): cint; cdecl;
  {$ENDIF}

  { Возвращает `PyModuleDef` для модуля. }
  PyModule_GetDef: function(Module: PPyObject): PPyModuleDef; cdecl;
  { Возвращает имя модуля как `str`. }
  PyModule_GetNameObject: function(Module: PPyObject): PPyObject; cdecl;
  { Импортирует модуль. }
  PyImport_ImportModule: function(Name: pansichar): PPyObject; cdecl;

  { Парсит аргументы. }
  PyArg_Parse: function(args: PPyObject; format: pansichar): cint; cdecl; varargs;
  { Парсит кортеж аргументов. }
  PyArg_ParseTuple: function(args: PPyObject; format: pansichar): cint; cdecl; varargs;
  { Парсит позиционные и именованные аргументы. }
  PyArg_ParseTupleAndKeywords: function(args, kwargs: PPyObject; format: pansichar; keywords: PPAnsiChar): cint; cdecl; varargs;
  { Парсит аргументы из `va_list`. }
  PyArg_VaParse: function(args: PPyObject; format: pansichar; va: Pointer): cint; cdecl;
  { Парсит позиционные и именованные аргументы из `va_list`. }
  PyArg_VaParseTupleAndKeywords: function(args, kwargs: PPyObject; format: pansichar; keywords: PPAnsiChar; va: Pointer): cint; cdecl;
  { Проверяет ключи в `kwargs`. }
  PyArg_ValidateKeywordArguments: function(kwargs: PPyObject): cint; cdecl;
  { Распаковывает кортеж. }
  PyArg_UnpackTuple: function(args: PPyObject; Name: pansichar; min, max: Py_ssize_t): cint; cdecl; varargs;

  { Создаёт объект по формату. }
  Py_BuildValue: function(format: pansichar): PPyObject; cdecl; varargs;
  { Создаёт объект по формату из `va_list`. }
  Py_VaBuildValue: function(format: pansichar; va: Pointer): PPyObject; cdecl;

  // --- Helper Functions ---
  { Инициализирует заголовок `PyModuleDef`. }
  procedure PyModuleDef_HEAD_INIT(var def: PyModuleDef); inline;
  { Создаёт и инициализирует модуль. }
  function Init(var Module: PyModuleDef; const NameModule: pansichar; constref VarSizeModule: Py_ssize_t = 0; DocModule: pansichar = ''): PPyObject;
  { Добавляет функцию в модуль. }
  function Add(var Module: PPyObject; const MethodDef: PPyMethodDef; const NameFunction: pansichar = nil): boolean;
  { Создаёт модуль и добавляет в него функции. }
  function Init(var Module: PyModuleDef; constref Fun: array of PPyMethodDef; const NameModule: pansichar; constref VarSizeModule: Py_ssize_t = 0; DocModule: pansichar = ''): PPyObject;
  { Удаляет функцию из модуля. }
  function Remove(var Module: PPyObject; const NameFunction: pansichar): boolean;
  { Заменяет функцию в модуле. }
  function Replace(var Module: PPyObject; const NameFunction: pansichar; const MethodDef: PPyMethodDef; const NewFunction: pansichar = nil): boolean;
  { Импортирует модуль. }
  function GetModule(const NameModule: pansichar): PPyObject; inline;
  { Уменьшает счетчик ссылок модуля. }
  procedure Close(var Module: PPyObject); inline;
  { Добавляет целочисленную константу. }
  function PyModule_AddIntMacro(Module: PPyObject; const C: clong; const Name: pansichar): cint; inline;
  { Добавляет строковую константу. }
  function PyModule_AddStringMacro(Module: PPyObject; const Value, Name: pansichar): cint; inline;

implementation

procedure PyModuleDef_HEAD_INIT(var def: PyModuleDef);
begin
  if not Assigned(PyModuleDef_Type) then Exit;
  PyObject_HEAD_INIT(@def.m_base, PyModuleDef_Type);
  def.m_base.m_init  := nil;
  def.m_base.m_index := 0;
  def.m_base.m_copy  := nil;
end;

function GetNameFunction(Name: pansichar; Func: PPyMethodDef): pansichar;
begin
  if Assigned(Name) then Result := Name
  else Result := Func^.ml_name;
end;

procedure WriteNameFunction(OkFlag: boolean; const PyModule: PPyObject; const NameFunction: pansichar);
begin
  if OkFlag then writeOk else WriteError;
  Write(PyModule_GetDef(PyModule)^.m_name, '.', NameFunction);
  writeln;
end;

procedure WriteModule(OkFlag: boolean; const NameModule: pansichar);
begin
  if OkFlag then writeOk else WriteError;
  WriteBox;
  Write(NameModule);
  writeln;
end;

function Init(var Module: PyModuleDef; const NameModule: pansichar; constref VarSizeModule: Py_ssize_t = 0; DocModule: pansichar = ''): PPyObject;
begin
  if not Assigned(PyModule_Create2) then
  begin
    Result := nil;
    Exit;
  end;
  PyModuleDef_HEAD_INIT(Module);
  Module.m_name := NameModule;
  Module.m_size := VarSizeModule;
  Module.m_doc  := DocModule;
  Result := PyModule_Create2(@Module, PYTHON_API_VERSION);
  if Assigned(Result) then
  begin
    {$IFDEF DEBUG}
    WriteModule(True, NameModule);
    {$ENDIF}
  end
  else
  begin
    PyErr_Clear;
    {$IF defined(PY_CONSOLE) or defined(DEBUG)}
    WriteModule(False, NameModule);
    {$ENDIF}
  end;
end;

function Add(var Module: PPyObject; const MethodDef: PPyMethodDef; const NameFunction: pansichar = nil): boolean;
var
  P: PPyObject;
begin
  Result := False;
  if (Module = nil) or (MethodDef = nil) then Exit;

  if Assigned(PyCFunction_NewEx) and Assigned(PyModule_AddObject) then
  begin
    P := PyCFunction_NewEx(MethodDef, nil, nil);
    if not Assigned(P) then
    begin
      PyErr_Clear();
      {$IF defined(PY_CONSOLE) or defined(DEBUG)}
      WriteNameFunction(False, Module, MethodDef^.ml_name);
      {$ENDIF}
      Exit;
    end;

    if PyModule_AddObject(Module, GetNameFunction(NameFunction, MethodDef), P) < 0 then
    begin
      Py_DECREF(P);
      {$IF defined(PY_CONSOLE) or defined(DEBUG)}
      WriteNameFunction(False, Module, GetNameFunction(NameFunction, MethodDef));
      {$ENDIF}
      PyErr_Clear;
      Exit;
    end;

    {$IFDEF DEBUG}
    WriteNameFunction(True, Module, GetNameFunction(NameFunction, MethodDef));
    {$ENDIF}
    Result := True;
  end
  else
  begin
    {$IF defined(PY_CONSOLE) or defined(DEBUG)}
    WriteNameFunction(False, Module, MethodDef^.ml_name);
    {$ENDIF}
  end;
end;

function Init(var Module: PyModuleDef; constref Fun: array of PPyMethodDef; const NameModule: pansichar; constref VarSizeModule: Py_ssize_t = 0; DocModule: pansichar = ''): PPyObject;
var
  i: integer;
begin
  Result := Init(Module, NameModule, VarSizeModule, DocModule);
  if Assigned(Result) then
    for i := 0 to High(Fun) do
      if Assigned(Fun[i]) then
        Add(Result, Fun[i], Fun[i]^.ml_name);
end;

function Remove(var Module: PPyObject; const NameFunction: pansichar): boolean;
begin
  if (Module = nil) or (NameFunction = nil) then
  begin
    Result := False;
    Exit;
  end;
  Result := (PyObject_HasAttrString(Module, NameFunction) <> 0) and
    (PyObject_DelAttrString(Module, NameFunction) = 0);
  if Result then
  begin
    {$IF defined(PY_CONSOLE) or defined(DEBUG)}
    writeDel;
    WriteNameFunction(True, Module, NameFunction);
    {$ENDIF}
  end
  else
  begin
    PyErr_Clear();
    {$IFDEF DEBUG}
    writeDel;
    WriteNameFunction(False, Module, NameFunction);
    {$ENDIF}
  end;
end;

function Replace(var Module: PPyObject; const NameFunction: pansichar; const MethodDef: PPyMethodDef; const NewFunction: pansichar = nil): boolean;
begin
  Result := Remove(Module, NameFunction) and Add(Module, MethodDef, NewFunction);
end;

function GetModule(const NameModule: pansichar): PPyObject;
begin
  if (NameModule = nil) or (not Assigned(PyImport_ImportModule)) then
  begin
    Result := nil;
    Exit;
  end;
  Result := PyImport_ImportModule(NameModule);
  if not Assigned(Result) then
  begin
    PyErr_Clear;
    {$IF defined(PY_CONSOLE) or defined(DEBUG)}
    WriteModule(False, NameModule);
    {$ENDIF}
  end;
end;

procedure Close(var Module: PPyObject);
begin
  Py_XDECREF(Module);
  Module := nil;
end;

function PyModule_AddIntMacro(Module: PPyObject; const C: clong; const Name: pansichar): cint;
begin
  Result := PyModule_AddIntConstant(Module, Name, C);
end;

function PyModule_AddStringMacro(Module: PPyObject; const Value, Name: pansichar): cint;
begin
  Result := PyModule_AddStringConstant(Module, Name, Value);
end;

initialization
  Pointer(PyModule_Create2) := GetProc('PyModule_Create2');
  Pointer(PyArg_Parse)      := GetProc('PyArg_Parse');
  Pointer(PyArg_ParseTuple) := GetProc('PyArg_ParseTuple');
  Pointer(PyArg_ParseTupleAndKeywords) := GetProc('PyArg_ParseTupleAndKeywords');
  Pointer(PyArg_VaParse)    := GetProc('PyArg_VaParse');
  Pointer(PyArg_VaParseTupleAndKeywords) := GetProc('PyArg_VaParseTupleAndKeywords');
  Pointer(PyArg_ValidateKeywordArguments) := GetProc('PyArg_ValidateKeywordArguments');
  Pointer(PyArg_UnpackTuple) := GetProc('PyArg_UnpackTuple');
  Pointer(Py_BuildValue)    := GetProc('Py_BuildValue');
  Pointer(Py_VaBuildValue)  := GetProc('Py_VaBuildValue');
  Pointer(PyModule_AddObject) := GetProc('PyModule_AddObject');
  Pointer(PyModule_AddIntConstant) := GetProc('PyModule_AddIntConstant');
  Pointer(PyModule_AddStringConstant) := GetProc('PyModule_AddStringConstant');
  Pointer(PyCFunction_NewEx) := GetProc('PyCFunction_NewEx');

  {$IFNDEF PY_LIMITED_API}
  Pointer(PyModule_AddFunctions) := GetProc('PyModule_AddFunctions');
  Pointer(PyCMethod_New)    := GetProc('PyCMethod_New');
  Pointer(PyModule_New)     := GetProc('PyModule_New');
  Pointer(PyModule_FromDefAndSpec2) := GetProc('PyModule_FromDefAndSpec2');
  Pointer(PyModule_ExecDef) := GetProc('PyModule_ExecDef');
  Pointer(PyModule_AddObjectRef) := GetProc('PyModule_AddObjectRef');
  Pointer(PyModule_Add)     := GetProc('PyModule_Add');
  Pointer(PyModule_SetDocString) := GetProc('PyModule_SetDocString');
  Pointer(PyModule_AddType) := GetProc('PyModule_AddType');
  {$ENDIF}
  Pointer(PyModule_GetNameObject) := GetProc('PyModule_GetNameObject');
  Pointer(PyModule_GetDef)  := GetProc('PyModule_GetDef');
  Pointer(PyModuleDef_Type) := GetProc('PyModuleDef_Type');
  Pointer(PyImport_ImportModule) := GetProc('PyImport_ImportModule');
end.
