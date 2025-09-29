﻿unit Daf.Rtti;

interface
uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Daf.Expression,
  Daf.Arrays;

type

  _T = record
  private
  public
    class function GUID<T: IInterface>: TGUID; overload; static;inline;
    class function GUID(const PInfo: PTypeInfo): TGUID; overload; static; inline;

    class function Default<T>: T; static;inline;

    class function UnitNameOf<T>: string; overload;static;inline;
    class function UnitNameOf(PInfo: PTypeInfo): string; overload;static;
    class function UnitNameOf(AClass: TClass): string; overload;static;

    class function NameOf<T>: string; overload; static;inline;
    class function NameOf(PInfo: PTypeInfo): string; overload; static;inline;

    class function IsObject(PInfo: PTypeInfo): Boolean;static;

    class function IsCollection(AClass: TClass): Boolean;static;
    class function IsDictionary(AClass: TClass): Boolean;static;

    class function ElementType<T>: PTypeInfo;overload; static;inline;
    class function ElementType(ATypeInfo: PTypeInfo): PTypeInfo;overload;static;

    class function PackageOf<T>: TRttiPackage;overload;static;inline;
    class function PackageOf(PInfo: PTypeInfo): TRttiPackage; overload; static;inline;
    class function PackageOf(AClass: TClass): TRttiPackage; overload; static;inline;

    class function Extends(Intf: PTypeInfo; Ancestor: PTypeInfo): Boolean; overload;static;
    class function Extends(Intf: PTypeInfo; Ancestor: PTypeInfo; ExcludeSelf: Boolean): Boolean; overload; static;

    class function HasProperty<T: class>(const PropName:string): Boolean; overload; static;
    class function HasProperty(T: TClass;const PropName:string): Boolean; overload; static;
    class function HasProperty(Instance: TObject;const PropName:string): Boolean; overload; static;

    class function GetConverFromOps(PInfo: PTypeInfo; Filter: TPredicate<TRttiMethod> = nil): TArray<TRttiMethod>;static;
  end;

  TRttiPackageHelper = class Helper for TRttiPackage
  public
    procedure DiscoverImpl<Intf: IInterface>(StrictExtensions: Boolean; Filter: TFilterSpec<TRttiType>; Action: TProc<TRttiInterfaceType, TRttiInstanceType>; ExcludeNameSpace: string = '');
    function AllTypes: TSmartArray<TRttiType>;
  end;

  TRttiPropertyHelper = class Helper for TRttiProperty
  public
    procedure SetValue(Instance: Pointer;const AValue: TValue);
  end;

  TRttiTypeHelper = class helper for TRttiType
  private
  public
    function IsGeneric: Boolean;
    function IsInterface: Boolean;
    function IsArray: Boolean;
    function IsCollection: Boolean;
    function IsDictionary: Boolean;
    function IsObject: Boolean;
    function IsPlain: Boolean;
    function Implements<Intf: IInterface>(StrictExtensions: Boolean = False): Boolean;
    function GetExtensions<Intf: IInterface>(StrictExtensions: Boolean = False): TSmartArray<TRttiInterfaceType>;
  end;

  TRttiInstanceTypeHelper = class helper for TRttiInstanceType
  public
  end;

  // Representa un marcador para un argumento genérico abierto
  _ = class
  end;

  TEnum = record
    class function ToString<T>(Value: T): string;static;inline;
  end;

  TGenericRTTI = class
  public
    class function GetGenericArguments(AType: TRttiType): TArray<TRttiType>;
    class function MakeGenericType(GenericType: TRttiType; const TypeArgs: array of TRttiType): TRttiType;
  end;

  TPropInjector = class
  public
    class procedure Assign<TTarget: class; TSource: class>(const Target: TTarget; const Source: TSource);
    class procedure AssignTo<TTarget: class; TSource: class>(const Source: TSource; const Target: TTarget);
  end;

function TryGetMethod(const Instance: TObject; const MethodName: string; out Method: TMethod): Boolean;
function GetInterfaceIID(const I: IInterface; var IID: TGUID): Boolean;
function GetRttiFromInterface(AIntf: IInterface; out RttiType: TRttiInterfaceType): Boolean;
function HasRtti(PInfo: PTypeInfo): Boolean;

implementation

uses
  System.StrUtils,
  Daf.Types;

function TryGetMethod(const Instance: TObject; const MethodName: string; out Method: TMethod): Boolean;
begin
  Method.Data := Instance;
  Method.Code := Instance.MethodAddress(MethodName);
  Result := Assigned(Method.Code);
end;

function HasRtti(PInfo: PTypeInfo): Boolean;
begin
  var
    RCtx := TRttiContext.Create;
  try
    var
    RttiType := RCtx.GetType(PInfo) as TRttiInterfaceType;
    Result := (ifHasRtti in RttiType.IntfFlags);
  finally
    RCtx.Free;
  end;
end;

function GetRttiFromInterface(AIntf: IInterface; out RttiType: TRttiInterfaceType): Boolean;
var
  obj: TObject;
  IntfType: TRttiInterfaceType;
  ctx: TRttiContext;
  tmpIntf: IInterface;
begin
  Result := False;
  ctx.Create;
  // get the implementing object...
  obj := AIntf as TObject;

  // enumerate the object's interfaces, looking for the
  // one that matches the input parameter...
  for IntfType in (ctx.GetType(obj.ClassType) as TRttiInstanceType).GetImplementedInterfaces do
  begin
    if not obj.GetInterface(IntfType.GUID, tmpIntf) then Continue;
    if AIntf = tmpIntf then
    begin
      RttiType := IntfType;
      Result := True;
      Exit;
    end;
    tmpIntf := nil;
  end;
  Ctx.Free;
end;

function GetPIMTOffset(const I: IInterface): integer;
// PIMT = Pointer to Interface Method Table
const
  AddByte = $04244483; // opcode for ADD DWORD PTR [ESP+4], Shortint
  AddLong = $04244481; // opcode for ADD DWORD PTR [ESP+4], Longint
type
  PAdjustSelfThunk = ^TAdjustSelfThunk;

  TAdjustSelfThunk = packed record
    case AddInstruction: longint of
      AddByte:
        (AdjustmentByte: shortint);
      AddLong:
        (AdjustmentLong: longint);
  end;

  PInterfaceMT = ^TInterfaceMT;

  TInterfaceMT = packed record
    QueryInterfaceThunk: PAdjustSelfThunk;
  end;

  TInterfaceRef = ^PInterfaceMT;
var
  QueryInterfaceThunk: PAdjustSelfThunk;
begin
  Result := -1;
  if Assigned(Pointer(I)) then
    try
      QueryInterfaceThunk := TInterfaceRef(I)^.QueryInterfaceThunk;
      case QueryInterfaceThunk.AddInstruction of
        AddByte:
          Result := -QueryInterfaceThunk.AdjustmentByte;
        AddLong:
          Result := -QueryInterfaceThunk.AdjustmentLong;
      end;
    except
      // Protect against non-Delphi or invalid interface references
    end;
end;

function GetInterfaceEntry(const I: IInterface): PInterfaceEntry;
var
  Offset: integer;
  Instance: TObject;
  InterfaceTable: PInterfaceTable;
  j: integer;
  CurrentClass: TClass;
begin
  Offset := GetPIMTOffset(I);
  Instance := TObject(I);
  if (Offset >= 0) and Assigned(Instance) then
  begin
    CurrentClass := Instance.ClassType;
    while Assigned(CurrentClass) do
    begin
      InterfaceTable := CurrentClass.GetInterfaceTable;
      if Assigned(InterfaceTable) then
        for j := 0 to InterfaceTable.EntryCount - 1 do
        begin
          Result := @InterfaceTable.Entries[j];
          if Result.IOffset = Offset then
            Exit;
        end;
      CurrentClass := CurrentClass.ClassParent
    end;
  end;
  Result := nil;
end;

function GetInterfaceIID(const I: IInterface; var IID: TGUID): Boolean;
var
  InterfaceEntry: PInterfaceEntry;
begin
  InterfaceEntry := GetInterfaceEntry(I);
  Result := Assigned(InterfaceEntry);
  if Result then
    IID := InterfaceEntry.IID;
end;

{ _T }

class function _T.Default<T>: T;
begin
  Result := System.Default(T);
end;

class function _T.Extends(Intf, Ancestor: PTypeInfo; ExcludeSelf: Boolean): Boolean;
begin
  if (Intf = Ancestor) and ExcludeSelf then Exit(False);
  Result := _T.Extends(Intf, Ancestor);
end;

class function _T.Extends(Intf, Ancestor: PTypeInfo): Boolean;
begin
  Result := False;

  if (Intf.Kind <> tkInterface) or (Ancestor.Kind <> tkInterface)then
    Exit;

  if(Intf = nil)or(Ancestor = nil)then
    Exit;

  if Intf = Ancestor then
    Exit(True);

  if Intf.TypeData.BaseType = nil then
    Exit;

  Result := Extends(Intf.TypeData.IntfParent^, Ancestor);
end;

class function _T.GUID<T>: TGUID;
begin
  Result := _T.GUID(TypeInfo(T));
end;

class function _T.GetConverFromOps(PInfo: PTypeInfo; Filter: TPredicate<TRttiMethod> = nil): TArray<TRttiMethod>;
begin
  Result := nil;
  var RC := TRttiContext.Create;
  try
    var RType := RC.GetType(PInfo);
    for var M in RType.GetMethods do
    begin
      if (M.Name = '&op_Implicit') and (M.ReturnType.Handle = PInfo) then
        if not Assigned(Filter) or Filter(M) then
          Result := Result + [M];
    end;
  finally
    RC.Free;
  end;

      // Probar si existe operador de conversion implicita

end;

class function _T.GUID(const PInfo: PTypeInfo): TGUID;
begin
  Result := PInfo.TypeData.GUID;
end;

class function _T.ElementType<T>: PTypeInfo;
begin
  Result := _T.ElementType(TypeInfo(T));
end;

class function _T.ElementType(ATypeInfo: PTypeInfo): PTypeInfo;
var
  ref: PPTypeInfo;
begin
  if ATypeInfo^.Kind = tkArray then
    ref := GetTypeData(ATypeInfo)^.ArrayData.ElType
  else if ATypeInfo^.Kind = tkDynArray then
    ref := GetTypeData(ATypeInfo).DynArrElType
  else
    ref := nil;
  if ref = nil then
    Exit(nil)
  else
    Exit(ref^);
end;

class function _T.HasProperty(T: TClass;const PropName:string): Boolean;
begin
  Result :=(GetPropInfo(T, PropName) <> nil);
end;

class function _T.HasProperty(Instance: TObject;const PropName:string): Boolean;
begin
  Result := Assigned(Instance) and HasProperty(Instance.ClassType, PropName);
end;

class function _T.HasProperty<T>(const PropName:string): Boolean;
begin
  Result := HasProperty(T, PropName);
end;

class function _T.IsCollection(AClass: TClass): Boolean;
begin
  if (AClass = nil) then Exit(False);
  if (AClass = TObject) then Exit(False);
  if AClass.QualifiedClassName.StartsWith('System.Generics.Collections.TList<', True) then
    Exit(True)
  else
    Result := IsCollection(AClass.ClassParent);
end;

class function _T.IsDictionary(AClass: TClass): Boolean;
begin
  if (AClass = nil) then Exit(False);
  if (AClass = TObject) then Exit(False);
  if AClass.QualifiedClassName.StartsWith('System.Generics.Collections.TDictionary<', True) then
    Exit(True)
  else
    Result := IsDictionary(AClass.ClassParent);
end;

class function _T.IsObject(PInfo: PTypeInfo): Boolean;
begin
  Result := PInfo.Kind = tkClass;
end;

class function _T.NameOf(PInfo: PTypeInfo):string;
begin
  Result := string(PInfo.Name);
end;

class function _T.NameOf<T>:string;
begin
  Result := _T.NameOf(TypeInfo(T));
end;

class function _T.UnitNameOf<T>:string;
begin
  Result :=_T.UnitNameOf(TypeInfo(T));
end;

class function _T.UnitNameOf(AClass: TClass):string;
begin
  Result := _T.UnitNameOf(AClass.ClassInfo);
end;

class function _T.UnitNameOf(PInfo: PTypeInfo):string;
begin
  Result := ChangeFileExt(TRttiContext.Create.GetType(PInfo).QualifiedName, '');
end;

class function _T.PackageOf(PInfo: PTypeInfo): TRttiPackage;
begin
  var RC := TRttiContext.Create;
  try
    Result := RC.GetType(PInfo).Package;
  finally
    RC.Free;
  end;
end;

class function _T.PackageOf(AClass: TClass): TRttiPackage;
begin
  Result := _T.PackageOf(AClass.ClassInfo);
end;

class function _T.PackageOf<T>: TRttiPackage;
begin
  Result := _T.PackageOf(TypeInfo(T));
end;

{ TRttiPackageHelper }

function TRttiPackageHelper.AllTypes: TSmartArray<TRttiType>;
begin
  Result := Self.GetTypes;
end;

procedure TRttiPackageHelper.DiscoverImpl<Intf>(StrictExtensions: Boolean; Filter: TFilterSpec<TRttiType>; Action: TProc<TRttiInterfaceType, TRttiInstanceType>; ExcludeNameSpace: string = '');
begin
  var Candidates := AllTypes.Where(
     function(T: TRttiType): Boolean
     begin
       Result := Filter.Eval(T) and T.Implements<Intf>(StrictExtensions);
     end
  ).Select<TRttiInstanceType>(
     function(T: TRttiType): TRttiInstanceType
     begin
       Result := T as TRttiInstanceType;
     end
  );

  for var RClass in Candidates do
  begin
    Action(RClass.GetExtensions<Intf>(StrictExtensions).First, RClass);
  end;
end;

{ TRttiPropertyHelper }

procedure TRttiPropertyHelper.SetValue(Instance: Pointer;const AValue: TValue);
begin
  var
  ValueToSet := AValue;
  if PropertyType is TRttiRecordType then
  begin
    // Probar si existe operador de conversion implicita
    for var M in PropertyType.GetMethods do
    begin
      if(M.Name = '&op_Implicit')then
      begin
        var
        P := M.GetParameters[0];
        if P.ParamType.Handle = ValueToSet.TypeInfo then
        begin
          ValueToSet := M.Invoke(GetValue(Instance),[ValueToSet]);
          inherited SetValue(Instance, ValueToSet);
          Break;
        end;
      end;
    end;
  end
  else
    SetPropValue(Instance, Self.Name, ValueToSet.AsVariant);
end;

{ TRttiTypeHelper }

function TRttiTypeHelper.GetExtensions<Intf>(StrictExtensions: Boolean = False): TSmartArray<TRttiInterfaceType>;
begin
  Result := nil;
  if not IsInstance then Exit;
  for var RIntf in AsInstance.GetImplementedInterfaces do
    if _T.Extends(RIntf.Handle, TypeInfo(Intf), StrictExtensions) then
      Result.Concat(RIntf);
end;

function TRttiTypeHelper.Implements<Intf>(StrictExtensions: Boolean = False): Boolean;
begin
  Result := False;
  if not IsInstance then Exit;
  for var RIntf in AsInstance.GetImplementedInterfaces do
    if _T.Extends(RIntf.Handle, TypeInfo(Intf), StrictExtensions) then Exit(True)
end;

function TRttiTypeHelper.IsGeneric: Boolean;
begin
  Result := Name.Contains('<');
end;

function TRttiTypeHelper.IsInterface: Boolean;
begin
  Result := InheritsFrom(TRttiInterfaceType);
end;

function TRttiTypeHelper.IsCollection: Boolean;
begin
  Result := (TypeKind = tkClass) and _T.IsCollection(AsInstance.MetaclassType)
end;

function TRttiTypeHelper.IsDictionary: Boolean;
begin
  Result := (TypeKind = tkClass) and _T.IsDictionary(AsInstance.MetaclassType)
end;

function TRttiTypeHelper.IsObject: Boolean;
begin
  Result := (TypeKind = tkClass) and not IsCollection;
end;

function TRttiTypeHelper.IsArray: Boolean;
begin
  Result := TypeKind in [tkDynArray, tkArray];
end;

function TRttiTypeHelper.IsPlain: Boolean;
begin
  Result := not (IsObject or IsCollection or IsDictionary or IsArray);
end;

{ TEnum }

class function TEnum.ToString<T>(Value: T): string;
begin
  Result := TRttiEnumerationType.GetName<T>(Value);
end;

{ TGenericRTTI }

class function TGenericRTTI.GetGenericArguments(AType: TRttiType): TArray<TRttiType>;
var
  Ctx: TRttiContext;
  QualifiedName: string;
  ArgList: TArray<string>;
  ArgType: TRttiType;
  I: Integer;
begin
  Ctx := TRttiContext.Create;
  QualifiedName := AType.QualifiedName;

  // Buscar apertura de genéricos
  if not ContainsText(QualifiedName, '<') then
    Exit(nil);

  QualifiedName := Copy(QualifiedName, Pos('<', QualifiedName) + 1, MaxInt);
  QualifiedName := Copy(QualifiedName, 1, Pos('>', QualifiedName) - 1);

  ArgList := QualifiedName.Split([',']);
  SetLength(Result, Length(ArgList));

  for I := 0 to High(ArgList) do
  begin
    ArgType := Ctx.FindType(Trim(ArgList[I]));
    if not Assigned(ArgType) then
      raise Exception.CreateFmt('Tipo genérico no encontrado: %s', [ArgList[I]]);
    Result[I] := ArgType;
  end;
end;

class function TGenericRTTI.MakeGenericType(GenericType: TRttiType; const TypeArgs: array of TRttiType): TRttiType;
var
  Ctx: TRttiContext;
  TI: PTypeInfo;
  Name: string;
  I: Integer;
  QualifiedName: string;
begin
  // Construir el nombre calificado como TMiClase<T1, T2>
  Name := GenericType.Name;
  QualifiedName := Name + '<';
  for I := Low(TypeArgs) to High(TypeArgs) do
  begin
    QualifiedName := QualifiedName + TypeArgs[I].QualifiedName;
    if I < High(TypeArgs) then
      QualifiedName := QualifiedName + ', ';
  end;
  QualifiedName := QualifiedName + '>';

  // Buscar el tipo construido en el contexto actual
  Ctx := TRttiContext.Create;
  TI := Ctx.FindType(QualifiedName).Handle;
  if not Assigned(TI) then
    raise Exception.CreateFmt('No se pudo construir tipo genérico: %s', [QualifiedName]);

  Result := Ctx.GetType(TI);
end;

class procedure TPropInjector.AssignTo<TTarget, TSource>(const Source: TSource; const Target: TTarget);
begin
  Assign(Target, Source);
end;

class procedure TPropInjector.Assign<TTarget, TSource>(const Target: TTarget; const Source: TSource);
var
  Ctx: TRttiContext;
  SrcType, DstType: TRttiType;
  SrcProp, DstProp: TRttiProperty;
begin
  //if not Assigned(Source) or not Assigned(Target) then  Exit;

  Ctx := TRttiContext.Create;
  try
    SrcType := Ctx.GetType(TypeInfo(TSource));
    DstType := Ctx.GetType(TypeInfo(TTarget));

    for SrcProp in SrcType.GetProperties do
    begin
      if not SrcProp.IsReadable then
        Continue;

      DstProp := DstType.GetProperty(SrcProp.Name);
      if not Assigned(DstProp) then
        Continue;

      if not DstProp.IsWritable then
        Continue;

      if not (DstProp.PropertyType.Handle = SrcProp.PropertyType.Handle) then
        Continue;

      DstProp.SetValue(TObject(Target), SrcProp.GetValue(TObject(Source)));
    end;
  finally
    Ctx.Free;
  end;
end;

initialization
  TRttiContext.KeepContext;
finalization
  TRttiContext.DropContext;
end.
