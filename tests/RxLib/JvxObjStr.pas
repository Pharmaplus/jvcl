{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvxObjStr.PAS, released on 2002-07-04.

The Initial Developers of the Original Code are: Fedor Koshevnikov, Igor Pavluk and Serge Korolev
Copyright (c) 1997, 1998 Fedor Koshevnikov, Igor Pavluk and Serge Korolev
Copyright (c) 2001,2002 SGB Software          
All Rights Reserved.

Last Modified: 2002-07-04

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://JVCL.sourceforge.net

Known Issues:
-----------------------------------------------------------------------------}
{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J+,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$I JEDI.INC}


unit JvxObjStr;

interface

uses SysUtils, Classes, RTLConsts;

type

{ TJvxObjectStrings }

  TDestroyEvent = procedure(Sender, AObject: TObject) of object;
  TObjectSortCompare = function (const S1, S2: string;
    Item1, Item2: TObject): Integer of object;

  TJvxObjectStrings = class(TStringList)
  private
    FOnDestroyObject: TDestroyEvent;
  protected
    procedure DestroyObject(AObject: TObject); virtual;
    procedure PutObject(Index: Integer; AObject: TObject); override;
  public
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Move(CurIndex, NewIndex: Integer); override;
    procedure Remove(Index: Integer);
    procedure ParseStrings(const Values: string);
    procedure SortList(Compare: TObjectSortCompare);
    property OnDestroyObject: TDestroyEvent read FOnDestroyObject
      write FOnDestroyObject;
  end;

{ TJvxHugeList class }

const
{$IFDEF WIN32}
  MaxHugeListSize = MaxListSize;
{$ELSE}
  MaxHugeListSize = (MaxLongint div SizeOf(Pointer)) - 4;
{$ENDIF}

type
{$IFDEF WIN32}
  TJvxHugeList = class(TList);
{$ELSE}
  TJvxHugeList = class(TObject)
  private
    FList: TMemoryStream;
    FCount: Longint;
    FCapacity: Longint;
  protected
    function Get(Index: Longint): Pointer;
    procedure Grow; virtual;
    procedure Put(Index: Longint; Item: Pointer);
    procedure SetCapacity(NewCapacity: Longint);
    procedure SetCount(NewCount: Longint);
  public
    destructor Destroy; override;
    function Add(Item: Pointer): Longint;
    procedure Clear;
    procedure Delete(Index: Longint);
    procedure Exchange(Index1, Index2: Longint);
    function Expand: TJvxHugeList;
    function First: Pointer;
    function IndexOf(Item: Pointer): Longint;
    procedure Insert(Index: Longint; Item: Pointer);
    function Last: Pointer;
    procedure Move(CurIndex, NewIndex: Longint);
    function Remove(Item: Pointer): Longint;
    procedure Pack;
    property Capacity: Longint read FCapacity write SetCapacity;
    property Count: Longint read FCount write SetCount;
    property Items[Index: Longint]: Pointer read Get write Put; default;
  end;
{$ENDIF WIN32}

{$IFDEF WIN32}

{ TJvxSortCollection }

type
  TItemSortCompare = function (Item1, Item2: TCollectionItem): Integer of object;

  TJvxSortCollection = class(TCollection)
  protected
    procedure QuickSort(L, R: Integer; Compare: TItemSortCompare); virtual;
  public
    procedure Sort(Compare: TItemSortCompare);
  end;

{$ENDIF WIN32}

implementation

uses {$IFNDEF WIN32} JvxVCLUtils, {$ENDIF} Consts, JvxStrUtils;

{ TJvxObjectStrings }

procedure QuickSort(SortList: TStrings; L, R: Integer;
  SCompare: TObjectSortCompare);
var
  I, J: Integer;
  P: TObject;
  S: string;
begin
  repeat
    I := L;
    J := R;
    P := SortList.Objects[(L + R) shr 1];
    S := SortList[(L + R) shr 1];
    repeat
      while SCompare(SortList[I], S, SortList.Objects[I], P) < 0 do Inc(I);
      while SCompare(SortList[J], S, SortList.Objects[J], P) > 0 do Dec(J);
      if I <= J then begin
        SortList.Exchange(I, J);
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(SortList, L, J, SCompare);
    L := I;
  until I >= R;
end;

procedure TJvxObjectStrings.DestroyObject(AObject: TObject);
begin
  if Assigned(FOnDestroyObject) then FOnDestroyObject(Self, AObject)
  else if AObject <> nil then AObject.Free;
end;

procedure TJvxObjectStrings.Clear;
var
  I: Integer;
begin
  if Count > 0 then begin
    Changing;
    for I := 0 to Count - 1 do Objects[I] := nil;
    BeginUpdate;
    try
      inherited Clear;
    finally
      EndUpdate;
    end;
    Changed;
  end;
end;

procedure TJvxObjectStrings.Delete(Index: Integer);
begin
  Objects[Index] := nil;
  inherited Delete(Index);
end;

procedure TJvxObjectStrings.Remove(Index: Integer);
begin
  inherited Delete(Index);
end;

procedure TJvxObjectStrings.Move(CurIndex, NewIndex: Integer);
var
  TempObject: TObject;
  TempString: string;
begin
  if CurIndex <> NewIndex then
  begin
    TempString := Get(CurIndex);
    TempObject := GetObject(CurIndex);
    inherited Delete(CurIndex);
    try
      InsertObject(NewIndex, TempString, TempObject);
    except
      DestroyObject(TempObject);
      raise;
    end;
  end;
end;

procedure TJvxObjectStrings.PutObject(Index: Integer; AObject: TObject);
begin
  Changing;
  BeginUpdate;
  try
    if (Index < Self.Count) and (Index >= 0) then
      DestroyObject(Objects[Index]);
    inherited PutObject(Index, AObject);
  finally
    EndUpdate;
  end;
  Changed;
end;

procedure TJvxObjectStrings.ParseStrings(const Values: string);
var
  Pos: Integer;
begin
  Pos := 1;
  BeginUpdate;
  try
    while Pos <= Length(Values) do Add(ExtractSubstr(Values, Pos, [';']));
  finally
    EndUpdate;
  end;
end;

procedure TJvxObjectStrings.SortList(Compare: TObjectSortCompare);
begin
  if Sorted then
{$IFDEF Delphi3_Up}
    Error(SSortedListError, 0);
{$ELSE}
    raise EListError.Create(LoadStr(SSortedListError));
{$ENDIF}
  if Count > 0 then begin
    BeginUpdate;
    try
      QuickSort(Self, 0, Count - 1, Compare);
    finally
      EndUpdate;
    end;
  end;
end;

{$IFNDEF WIN32}

{ TJvxHugeList }

function ReturnAddr: Pointer; assembler;
asm
        MOV     AX,[BP].Word[2]
        MOV     DX,[BP].Word[4]
end;

procedure ListError(Index: Longint);
begin
  raise EListError.Create(LoadStr(SListIndexError) +
    Format(' (%d)', [Index])) at ReturnAddr;
end;

destructor TJvxHugeList.Destroy;
begin
  Clear;
end;

function TJvxHugeList.Add(Item: Pointer): Longint;
begin
  Result := FCount;
  if Result = FCapacity then Grow;
  FList.Position := Result * SizeOf(Pointer);
  FList.WriteBuffer(Item, SizeOf(Pointer));
  Inc(FCount);
end;

procedure TJvxHugeList.Clear;
begin
  SetCount(0);
  SetCapacity(0);
end;

procedure TJvxHugeList.Delete(Index: Longint);
begin
  if (Index < 0) or (Index >= FCount) then ListError(Index);
  Dec(FCount);
  if Index < FCount then
    HugeMove(FList.Memory, Index, Index + 1, FCount - Index);
end;

function TJvxHugeList.Get(Index: Longint): Pointer;
begin
  if (Index < 0) or (Index >= FCount) then ListError(Index);
  FList.Position := Index * SizeOf(Pointer);
  FList.ReadBuffer(Result, SizeOf(Pointer));
end;

procedure TJvxHugeList.Put(Index: Longint; Item: Pointer);
begin
  if (Index < 0) or (Index >= FCount) then ListError(Index);
  FList.Position := Index * SizeOf(Pointer);
  FList.WriteBuffer(Item, SizeOf(Pointer));
end;

procedure TJvxHugeList.Exchange(Index1, Index2: Longint);
var
  Item: Pointer;
begin
  Item := Get(Index1);
  Put(Index1, Get(Index2));
  Put(Index2, Item);
end;

function TJvxHugeList.Expand: TJvxHugeList;
begin
  if FCount = FCapacity then Grow;
  Result := Self;
end;

function TJvxHugeList.First: Pointer;
begin
  Result := Get(0);
end;

procedure TJvxHugeList.Grow;
var
  Delta: Longint;
begin
  if FCapacity > 8 then Delta := 16
  else if FCapacity > 4 then Delta := 8
  else Delta := 4;
  SetCapacity(FCapacity + Delta);
end;

function TJvxHugeList.IndexOf(Item: Pointer): Longint;
begin
  Result := 0;
  while (Result < FCount) and (Get(Result) <> Item) do
    Inc(Result);
  if Result = FCount then Result := -1;
end;

procedure TJvxHugeList.Insert(Index: Longint; Item: Pointer);
begin
  if (Index < 0) or (Index > FCount) then ListError(Index);
  if FCount = FCapacity then Grow;
  if Index < FCount then
    HugeMove(FList.Memory, Index + 1, Index, FCount - Index);
  FList.Position := Index * SizeOf(Pointer);
  FList.WriteBuffer(Item, SizeOf(Pointer));
  Inc(FCount);
end;

function TJvxHugeList.Last: Pointer;
begin
  Result := Get(FCount - 1);
end;

procedure TJvxHugeList.Move(CurIndex, NewIndex: Longint);
var
  Item: Pointer;
begin
  if CurIndex <> NewIndex then begin
    if (NewIndex < 0) or (NewIndex >= FCount) then ListError(NewIndex);
    Item := Get(CurIndex);
    Delete(CurIndex);
    Insert(NewIndex, Item);
  end;
end;

function TJvxHugeList.Remove(Item: Pointer): Longint;
begin
  Result := IndexOf(Item);
  if Result <> -1 then Delete(Result);
end;

procedure TJvxHugeList.Pack;
var
  I: Longint;
begin
  for I := FCount - 1 downto 0 do
    if Items[I] = nil then Delete(I);
end;

procedure TJvxHugeList.SetCapacity(NewCapacity: Longint);
var
  NewList: TMemoryStream;
begin
  if (NewCapacity < FCount) or (NewCapacity > MaxHugeListSize) then
    ListError(NewCapacity);
  if NewCapacity <> FCapacity then begin
    if NewCapacity = 0 then NewList := nil
    else begin
      NewList := TMemoryStream.Create;
      NewList.SetSize(NewCapacity * SizeOf(Pointer));
      if FCount <> 0 then begin
        FList.Position := 0;
        FList.ReadBuffer(NewList.Memory^, FCount * SizeOf(Pointer));
      end;
    end;
    if FCapacity <> 0 then FList.Free;
    FList := NewList;
    FCapacity := NewCapacity;
  end;
end;

procedure TJvxHugeList.SetCount(NewCount: Longint);
begin
  if (NewCount < 0) or (NewCount > MaxHugeListSize) then
    ListError(NewCount);
  if NewCount > FCapacity then SetCapacity(NewCount);
  FCount := NewCount;
end;

{$ENDIF}

{$IFDEF WIN32}

{ TJvxSortCollection }

procedure TJvxSortCollection.QuickSort(L, R: Integer; Compare: TItemSortCompare);
var
  I, J: Integer;
  P, P1, P2: TCollectionItem;
begin
  repeat
    I := L;
    J := R;
    P := Items[(L + R) shr 1];
    repeat
      while Compare(Items[I], P) < 0 do Inc(I);
      while Compare(Items[J], P) > 0 do Dec(J);
      if I <= J then begin
        P1 := Items[I];
        P2 := Items[J];
        P1.Index := J;
        P2.Index := I;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(L, J, Compare);
    L := I;
  until I >= R;
end;

procedure TJvxSortCollection.Sort(Compare: TItemSortCompare);
begin
  if Count > 0 then begin
    BeginUpdate;
    try
      QuickSort(0, Count - 1, Compare);
    finally
      EndUpdate;
    end;
  end;
end;

{$ENDIF WIN32}

end.
