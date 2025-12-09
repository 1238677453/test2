{$mode fpc}
{$I config.inc}
library test;

uses
  ctypes,
  python,
  py_pymem,
  py_longobject,
  py_unicodeobject,
  py_modsupport;

 {
  Тестовая функция для проверки работы с PyLongObject.
  Принимает Python int, умножает его на 2 и возвращает результат.
}
  function py_test(self, args: PPyObject): PPyObject; cdecl;
  var
    pylong: PPyObject;
  begin
    if PyArg_ParseTuple(args, 'O', @pylong) = 0 then
    begin
      writeln('Error - PyArg_ParseTuple in py_test');
      Result := nil;
      Exit;
    end;
    writeln('>', PyLong_Type^.tp_basicsize);
    writeln('>', PyLong_Type^.tp_itemsize);
    writeln('>', Sizeof(PyLong_Type^));

    Result := PyLong_FromLong(PyLong_AsLong(pylong) * 2);
  end;

{
  Тестовая функция для проверки работы с PyUnicodeObject.
  Принимает Python str и возвращает его длину.
}
  function py_str(self, args: PPyObject): PPyObject; cdecl;
  var
    pyStr: PPyObject;
  begin
    if PyArg_ParseTuple(args, 'O', @pyStr) = 0 then
    begin
      writeln('Error - PyArg_ParseTuple in py_str');
      Result := nil;
      Exit;
    end;
    Result := PyLong_FromSsize_t(PyUnicode_GET_LENGTH(pyStr));
  end;

{
  Тестовая функция для проверки работы с PyMem_*.
  Выделяет и освобождает память.
}
  function py_mem_test(self, args: PPyObject): PPyObject; cdecl;
  var
    mem: Pointer;
  begin
    mem := PyMem_Malloc(1024);
    if mem <> nil then
    begin
      PyMem_Free(mem);
      Result := PyLong_FromLong(1); // Success
    end
    else
    begin
      Result := PyLong_FromLong(0); // Failure
    end;
  end;

{
  Тестовая функция для проверки работы с PyModule_*.
  Добавляет константу в модуль.
}
  function py_mod_test(self, args: PPyObject): PPyObject; cdecl;
  begin
    if PyModule_AddIntConstant(self, 'my_constant', 123) = 0 then
      Result := PyLong_FromLong(1) // Success
    else
      Result := PyLong_FromLong(0); // Failure
  end;

const
  TestMethods: array[0..3] of PyMethodDef = (
    (ml_name: 'py_test'; ml_meth: @py_test; ml_flags: METH_VARARGS;
    ml_doc: 'Test function for PyLongObject.'),
    (ml_name: 'py_str'; ml_meth: @py_str; ml_flags: METH_VARARGS;
    ml_doc: 'Test function for PyUnicodeObject.'),
    (ml_name: 'py_mem_test'; ml_meth: @py_mem_test; ml_flags: METH_NOARGS;
    ml_doc: 'Test function for PyMem API.'),
    (ml_name: 'py_mod_test'; ml_meth: @py_mod_test; ml_flags: METH_NOARGS;
    ml_doc: 'Test function for PyModule API.')
    );

  Test_ModuleDef: PyModuleDef = ();


  function PyInit_test: PPyObject; cdecl;
  begin
    Result := Init(Test_ModuleDef, 'test');
    if Assigned(Result) then
      Add(Result, @TestMethods[0]);
    Add(Result, @TestMethods[1]);
    Add(Result, @TestMethods[2]);
    Add(Result, @TestMethods[3]);
  end;


exports
  PyInit_test;

begin
end.