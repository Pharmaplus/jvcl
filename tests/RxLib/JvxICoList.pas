{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvxIcoList.PAS, released on 2002-07-04.

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

unit JvxIcoList;

interface


uses Messages, {$IFDEF WIN32} Windows, {$ELSE} WinTypes, WinProcs, {$ENDIF}
  SysUtils, Classes, Graphics;

type

{ TJvxIconList class }

  TJvxIconList = class(TPersistent)
  private
    FList: TList;
    FUpdateCount: Integer;
    FOnChange: TNotifyEvent;
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
    procedure SetUpdateState(Updating: Boolean);
    procedure IconChanged(Sender: TObject);
    function AddIcon(Icon: TIcon): Integer;
  protected
    procedure Changed; virtual;
    procedure DefineProperties(Filer: TFiler); override;
    function Get(Index: Integer): TIcon; virtual;
    function GetCount: Integer; virtual;
    procedure Put(Index: Integer; Icon: TIcon); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Icon: TIcon): Integer; virtual;
    function AddResource(Instance: THandle; ResId: PChar): Integer; virtual;
    procedure Assign(Source: TPersistent); override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure Clear; virtual;
    procedure Delete(Index: Integer); virtual;
    procedure Exchange(Index1, Index2: Integer); virtual;
    function IndexOf(Icon: TIcon): Integer; virtual;
    procedure Insert(Index: Integer; Icon: TIcon); virtual;
    procedure InsertResource(Index: Integer; Instance: THandle;
      ResId: PChar); virtual;
    procedure LoadResource(Instance: THandle; const ResIds: array of PChar);
    procedure LoadFromStream(Stream: TStream); virtual;
    procedure Move(CurIndex, NewIndex: Integer); virtual;
    procedure SaveToStream(Stream: TStream); virtual;
    property Count: Integer read GetCount;
    property Icons[Index: Integer]: TIcon read Get write Put; default;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

{ TJvxIconList }

constructor TJvxIconList.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

destructor TJvxIconList.Destroy;
begin
  FOnChange := nil;
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TJvxIconList.BeginUpdate;
begin
  if FUpdateCount = 0 then SetUpdateState(True);
  Inc(FUpdateCount);
end;

procedure TJvxIconList.Changed;
begin
  if (FUpdateCount = 0) and Assigned(FOnChange) then FOnChange(Self);
end;

procedure TJvxIconList.EndUpdate;
begin
  Dec(FUpdateCount);
  if FUpdateCount = 0 then SetUpdateState(False);
end;

procedure TJvxIconList.ReadData(Stream: TStream);
var
  Len, Cnt: Longint;
  I: Integer;
  Icon: TIcon;
  Mem: TMemoryStream;
begin
  BeginUpdate;
  try
    Clear;
    Mem := TMemoryStream.Create;
    try
      Stream.Read(Cnt, SizeOf(Longint));
      for I := 0 to Cnt - 1 do begin
        Stream.Read(Len, SizeOf(Longint));
        if Len > 0 then begin
          Icon := TIcon.Create;
          try
            Mem.SetSize(Len);
            Stream.Read(Mem.Memory^, Len);
            Mem.Position := 0;
            Icon.LoadFromStream(Mem);
            AddIcon(Icon);
          except
            Icon.Free;
            raise;
          end;
        end
        else AddIcon(nil);
      end;
    finally
      Mem.Free;
    end;
  finally
    EndUpdate;
  end;
end;

procedure TJvxIconList.WriteData(Stream: TStream);
var
  I: Integer;
  Len: Longint;
  Mem: TMemoryStream;
begin
  Mem := TMemoryStream.Create;
  try
    Len := FList.Count;
    Stream.Write(Len, SizeOf(Longint));
    for I := 0 to FList.Count - 1 do begin
      Mem.Clear;
      if (Icons[I] <> nil) and not Icons[I].Empty then begin
        Icons[I].SaveToStream(Mem);
        Len := Mem.Size;
      end
      else Len := 0;
      Stream.Write(Len, SizeOf(Longint));
      if Len > 0 then Stream.Write(Mem.Memory^, Mem.Size);
    end;
  finally
    Mem.Free;
  end;
end;

procedure TJvxIconList.DefineProperties(Filer: TFiler);

{$IFDEF WIN32}
  function DoWrite: Boolean;
  var
    I: Integer;
    Ancestor: TJvxIconList;
  begin
    Ancestor := TJvxIconList(Filer.Ancestor);
    if (Ancestor <> nil) and (Ancestor.Count = Count) and (Count > 0) then
    begin
      Result := False;
      for I := 0 to Count - 1 do begin
        Result := Icons[I] <> Ancestor.Icons[I];
        if Result then Break;
      end
    end
    else Result := Count > 0;
  end;
{$ENDIF}

begin
  Filer.DefineBinaryProperty('Icons', ReadData, WriteData,
    {$IFDEF WIN32} DoWrite {$ELSE} Count > 0 {$ENDIF});
end;

function TJvxIconList.Get(Index: Integer): TIcon;
begin
  Result := TObject(FList[Index]) as TIcon;
end;

function TJvxIconList.GetCount: Integer;
begin
  Result := FList.Count;
end;

procedure TJvxIconList.IconChanged(Sender: TObject);
begin
  Changed;
end;

procedure TJvxIconList.Put(Index: Integer; Icon: TIcon);
begin
  BeginUpdate;
  try
    if Index = Count then Add(nil);
    if Icons[Index] = nil then FList[Index] := TIcon.Create;
    Icons[Index].OnChange := IconChanged;
    Icons[Index].Assign(Icon);
  finally
    EndUpdate;
  end;
end;

function TJvxIconList.AddIcon(Icon: TIcon): Integer;
begin
  Result := FList.Add(Icon);
  if Icon <> nil then Icon.OnChange := IconChanged;
  Changed;
end;

function TJvxIconList.Add(Icon: TIcon): Integer;
var
  Ico: TIcon;
begin
  Ico := TIcon.Create;
  try
    Ico.Assign(Icon);
    Result := AddIcon(Ico);
  except
    Ico.Free;
    raise;
  end;
end;

function TJvxIconList.AddResource(Instance: THandle; ResId: PChar): Integer;
var
  Ico: TIcon;
begin
  Ico := TIcon.Create;
  try
    Ico.Handle := LoadIcon(Instance, ResId);
    Result := AddIcon(Ico);
  except
    Ico.Free;
    raise;
  end;
end;

procedure TJvxIconList.Assign(Source: TPersistent);
var
  I: Integer;
begin
  if Source = nil then Clear
  else if Source is TJvxIconList then begin
    BeginUpdate;
    try
      Clear;
      for I := 0 to TJvxIconList(Source).Count - 1 do
        Add(TJvxIconList(Source)[I]);
    finally
      EndUpdate;
    end;
  end
  else if Source is TIcon then begin
    BeginUpdate;
    try
      Clear;
      Add(TIcon(Source));
    finally
      EndUpdate;
    end;
  end
  else inherited Assign(Source);
end;

procedure TJvxIconList.Clear;
var
  I: Integer;
begin
  BeginUpdate;
  try
    for I := FList.Count - 1 downto 0 do Delete(I);
  finally
    EndUpdate;
  end;
end;

procedure TJvxIconList.Delete(Index: Integer);
var
  Icon: TIcon;
begin
  Icon := Icons[Index];
  if Icon <> nil then begin
    Icon.OnChange := nil;
    Icon.Free;
  end;
  FList.Delete(Index);
  Changed;
end;

procedure TJvxIconList.Exchange(Index1, Index2: Integer);
begin
  FList.Exchange(Index1, Index2);
  Changed;
end;

function TJvxIconList.IndexOf(Icon: TIcon): Integer;
begin
  Result := FList.IndexOf(Icon);
end;

procedure TJvxIconList.InsertResource(Index: Integer; Instance: THandle;
  ResId: PChar);
var
  Ico: TIcon;
begin
  Ico := TIcon.Create;
  try
    Ico.Handle := LoadIcon(Instance, ResId);
    FList.Insert(Index, Ico);
    Ico.OnChange := IconChanged;
  except
    Ico.Free;
    raise;
  end;
  Changed;
end;

procedure TJvxIconList.Insert(Index: Integer; Icon: TIcon);
var
  Ico: TIcon;
begin
  Ico := TIcon.Create;
  try
    Ico.Assign(Icon);
    FList.Insert(Index, Ico);
    Ico.OnChange := IconChanged;
  except
    Ico.Free;
    raise;
  end;
  Changed;
end;

procedure TJvxIconList.LoadResource(Instance: THandle; const ResIds: array of PChar);
var
  I: Integer;
begin
  BeginUpdate;
  try
    for I := Low(ResIds) to High(ResIds) do
      AddResource(Instance, ResIds[I]);
  finally
    EndUpdate;
  end;
end;

procedure TJvxIconList.Move(CurIndex, NewIndex: Integer);
begin
  FList.Move(CurIndex, NewIndex);
  Changed;
end;

procedure TJvxIconList.SetUpdateState(Updating: Boolean);
begin
  if not Updating then Changed;
end;

procedure TJvxIconList.LoadFromStream(Stream: TStream);
begin
  ReadData(Stream);
end;

procedure TJvxIconList.SaveToStream(Stream: TStream);
begin
  WriteData(Stream);
end;

end.
