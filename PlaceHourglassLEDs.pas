{==============================================================================
 ELECTRONIC HOURGLASS
 Final 12 x 24 RGB LED Matrix Placement
 -------------------------------------------------------------------------------
 Matrix:
     X = 0..11
     Z = 0..23

 Chat Generated for automated LED Placement

 Detection:
     X coordinate from COL_SCAN0..COL_SCAN11
     Z coordinate from R0/G0/B0..R23/G23/B23

 IMPORTANT:
     This script ONLY changes Component.X and Component.Y.

     It does NOT modify:
       - pads
       - footprint primitives
       - rotation
       - layers
       - designators
       - comments
       - strings
       - selected state
       - locking
       - nets

==============================================================================}


Const

    {================ GRID SETTINGS =================}

    PitchXMM  = 5.00;
    PitchZMM  = 5.00;

    { X0/Z0 location relative to PCB document origin }

    OriginXMM = 100.00;
    OriginYMM = 100.00;


    {================ MATRIX SIZE =================}

    MatrixXCount      = 12;
    MatrixZCount      = 24;
    ExpectedLEDCount  = 288;



{==============================================================================
 BASIC HELPERS
==============================================================================}


Function IsDigit(C : Char) : Boolean;
Begin
    Result := (C >= '0') And (C <= '9');
End;



{------------------------------------------------------------------------------
 Finds Token inside S and reads the integer immediately after it.

 Example:

     LED.COL_SCAN7

 gives:

     Value = 7
------------------------------------------------------------------------------}

Function ParseNumberAfterToken(
    S         : String;
    Token     : String;
    Var Value : Integer
) : Boolean;

Var
    U       : String;
    T       : String;
    P       : Integer;
    I       : Integer;
    NumText : String;

Begin

    Result := False;
    Value  := -1;

    U := UpperCase(S);
    T := UpperCase(Token);

    P := Pos(T, U);

    If P = 0 Then
        Exit;

    I := P + Length(T);

    NumText := '';

    While (I <= Length(U)) And IsDigit(U[I]) Do
    Begin

        NumText := NumText + U[I];

        I := I + 1;

    End;


    If NumText = '' Then
        Exit;


    Value := StrToInt(NumText);

    Result := True;

End;



{------------------------------------------------------------------------------
 Returns final token of hierarchical net name.

 Examples:

     LED.R12   -> R12
     LED/R12   -> R12
     LED:R12   -> R12
     R12       -> R12
------------------------------------------------------------------------------}

Function GetFinalNetToken(NetName : String) : String;

Var
    U : String;
    I : Integer;

Begin

    U := UpperCase(NetName);

    Result := U;


    For I := Length(U) Downto 1 Do
    Begin

        If (U[I] = '.') Or
           (U[I] = '/') Or
           (U[I] = ':') Then
        Begin

            Result :=
                Copy(
                    U,
                    I + 1,
                    Length(U) - I
                );

            Exit;

        End;

    End;

End;



{------------------------------------------------------------------------------
 Extract Z coordinate from RGB net.

 Accepted:

     R0 .. R23
     G0 .. G23
     B0 .. B23
------------------------------------------------------------------------------}

Function ParseZNet(
    NetName : String;
    Var Z   : Integer
) : Boolean;

Var
    Tail    : String;
    NumText : String;
    I       : Integer;

Begin

    Result := False;

    Z := -1;


    Tail := GetFinalNetToken(NetName);


    If Length(Tail) < 2 Then
        Exit;


    If Not (
        (Tail[1] = 'R') Or
        (Tail[1] = 'G') Or
        (Tail[1] = 'B')
    ) Then
        Exit;


    NumText :=
        Copy(
            Tail,
            2,
            Length(Tail) - 1
        );


    If NumText = '' Then
        Exit;


    For I := 1 To Length(NumText) Do
    Begin

        If Not IsDigit(NumText[I]) Then
            Exit;

    End;


    Z := StrToInt(NumText);


    If (Z < 0) Or
       (Z >= MatrixZCount) Then
        Exit;


    Result := True;

End;



{==============================================================================
 DETERMINE MATRIX COORDINATE OF COMPONENT
==============================================================================}


Function GetPixelCoordinates(
    Comp   : IPCB_Component;
    Var PX : Integer;
    Var PZ : Integer
) : Boolean;

Var

    GI      : IPCB_GroupIterator;
    Pad     : IPCB_Pad;

    NetName : String;

    TempX   : Integer;
    TempZ   : Integer;

    FoundX  : Boolean;
    FoundZ  : Boolean;

Begin

    Result := False;

    PX := -1;
    PZ := -1;

    FoundX := False;
    FoundZ := False;


    GI := Comp.GroupIterator_Create;


    If GI = Nil Then
        Exit;


    Try

        GI.AddFilter_ObjectSet(
            MkSet(ePadObject)
        );


        Pad := GI.FirstPCBObject;


        While Pad <> Nil Do
        Begin


            If Pad.Net <> Nil Then
            Begin

                NetName := Pad.Net.Name;


                {==========================================================
                 FIND X FROM COL_SCAN
                ==========================================================}

                If ParseNumberAfterToken(
                    NetName,
                    'COL_SCAN',
                    TempX
                ) Then
                Begin


                    If (TempX >= 0) And
                       (TempX < MatrixXCount) Then
                    Begin


                        { Reject component connected to multiple columns }

                        If FoundX And
                           (PX <> TempX) Then
                            Exit;


                        PX := TempX;

                        FoundX := True;

                    End;

                End;



                {==========================================================
                 FIND Z FROM R/G/B NET
                ==========================================================}

                If ParseZNet(
                    NetName,
                    TempZ
                ) Then
                Begin


                    If FoundZ Then
                    Begin

                        { All RGB nets must correspond
                          to same Z level }

                        If PZ <> TempZ Then
                            Exit;

                    End
                    Else
                    Begin

                        PZ := TempZ;

                        FoundZ := True;

                    End;

                End;

            End;


            Pad := GI.NextPCBObject;

        End;


        Result := FoundX And FoundZ;


    Finally

        Comp.GroupIterator_Destroy(GI);

    End;

End;



{==============================================================================
 PIPE-SEPARATED FIELD HELPER
==============================================================================}


{------------------------------------------------------------------------------
 Internal entry format:

     LED123|7|14

 Field 0 = Designator
 Field 1 = X
 Field 2 = Z
------------------------------------------------------------------------------}

Function GetPipeField(
    S          : String;
    FieldIndex : Integer
) : String;

Var

    CurrentField : Integer;
    StartPos     : Integer;
    I            : Integer;

Begin

    Result := '';

    CurrentField := 0;

    StartPos := 1;


    For I := 1 To Length(S) + 1 Do
    Begin


        If (I > Length(S)) Or
           (S[I] = '|') Then
        Begin


            If CurrentField = FieldIndex Then
            Begin

                Result :=
                    Copy(
                        S,
                        StartPos,
                        I - StartPos
                    );

                Exit;

            End;


            CurrentField :=
                CurrentField + 1;

            StartPos :=
                I + 1;

        End;

    End;

End;



{==============================================================================
 MAIN PLACEMENT PROCEDURE
==============================================================================}


Procedure PlaceLEDMatrix;

Var

    Board        : IPCB_Board;

    Iterator     : IPCB_BoardIterator;
    Comp         : IPCB_Component;

    MoveList     : TStringList;
    CoordList    : TStringList;

    PX           : Integer;
    PZ           : Integer;

    I            : Integer;

    Designator   : String;
    Entry        : String;
    CoordKey     : String;

    NewX         : TCoord;
    NewY         : TCoord;

    MoveCount    : Integer;

    DuplicateMap : Boolean;

Begin


    {==========================================================================
     GET ACTIVE PCB
    ==========================================================================}


    If PCBServer = Nil Then
    Begin

        ShowMessage(
            'PCBServer is not available.'
        );

        Exit;

    End;


    Board := PCBServer.GetCurrentPCBBoard;


    If Board = Nil Then
    Begin

        ShowMessage(
            'No PCB document is active.' +
            #13#10 +
            'Open FullSheet.PcbDoc and run again.'
        );

        Exit;

    End;



    {==========================================================================
     CREATE READ-ONLY DISCOVERY LISTS
    ==========================================================================}


    MoveList :=
        TStringList.Create;

    CoordList :=
        TStringList.Create;


    Try


        DuplicateMap := False;



        {======================================================================
         DISCOVER MATRIX LEDS

         Nothing is modified here.
        ======================================================================}


        Iterator :=
            Board.BoardIterator_Create;


        If Iterator = Nil Then
        Begin

            ShowMessage(
                'Could not create PCB component iterator.'
            );

            Exit;

        End;


        Try


            Iterator.AddFilter_ObjectSet(
                MkSet(eComponentObject)
            );


            Iterator.AddFilter_LayerSet(
                AllLayers
            );


            Iterator.AddFilter_Method(
                eProcessAll
            );


            Comp :=
                Iterator.FirstPCBObject;


            While Comp <> Nil Do
            Begin


                If GetPixelCoordinates(
                    Comp,
                    PX,
                    PZ
                ) Then
                Begin


                    Designator :=
                        Comp.Name.Text;


                    Entry :=
                        Designator +
                        '|' +
                        IntToStr(PX) +
                        '|' +
                        IntToStr(PZ);


                    MoveList.Add(
                        Entry
                    );


                    CoordKey :=
                        IntToStr(PX) +
                        ',' +
                        IntToStr(PZ);


                    If CoordList.IndexOf(
                        CoordKey
                    ) >= 0 Then
                    Begin

                        DuplicateMap :=
                            True;

                    End
                    Else
                    Begin

                        CoordList.Add(
                            CoordKey
                        );

                    End;

                End;


                Comp :=
                    Iterator.NextPCBObject;

            End;


        Finally

            Board.BoardIterator_Destroy(
                Iterator
            );

        End;



        {======================================================================
         VALIDATE MATRIX BEFORE MOVING ANYTHING
        ======================================================================}


        If MoveList.Count <> ExpectedLEDCount Then
        Begin

            ShowMessage(
                'PRE-FLIGHT FAILED' +
                #13#10#13#10 +

                'Expected LEDs: ' +
                IntToStr(ExpectedLEDCount) +
                #13#10 +

                'Detected LEDs: ' +
                IntToStr(MoveList.Count) +
                #13#10#13#10 +

                'Nothing was moved.'
            );

            Exit;

        End;



        If DuplicateMap Then
        Begin

            ShowMessage(
                'PRE-FLIGHT FAILED' +
                #13#10#13#10 +

                'Duplicate X/Z coordinate detected.' +
                #13#10 +

                'Nothing was moved.'
            );

            Exit;

        End;



        If CoordList.Count <> ExpectedLEDCount Then
        Begin

            ShowMessage(
                'PRE-FLIGHT FAILED' +
                #13#10#13#10 +

                'Unique coordinates: ' +
                IntToStr(CoordList.Count) +
                #13#10 +

                'Expected: ' +
                IntToStr(ExpectedLEDCount) +
                #13#10#13#10 +

                'Nothing was moved.'
            );

            Exit;

        End;



        {======================================================================
         MOVE ALL 288 LEDS
        ======================================================================}


        MoveCount := 0;


        For I :=
            0 To MoveList.Count - 1 Do
        Begin


            Entry :=
                MoveList[I];


            Designator :=
                GetPipeField(
                    Entry,
                    0
                );


            PX :=
                StrToInt(
                    GetPipeField(
                        Entry,
                        1
                    )
                );


            PZ :=
                StrToInt(
                    GetPipeField(
                        Entry,
                        2
                    )
                );



            {------------------------------------------------------------------
             Re-fetch component after discovery iterator has been destroyed
            ------------------------------------------------------------------}


            Comp :=
                Board.GetPcbComponentByRefDes(
                    Designator
                );


            If Comp = Nil Then
            Begin

                ShowMessage(
                    'PLACEMENT ABORTED' +
                    #13#10#13#10 +

                    'Could not find:' +
                    #13#10 +

                    Designator +
                    #13#10#13#10 +

                    'Already moved: ' +
                    IntToStr(MoveCount)
                );

                Exit;

            End;



            {------------------------------------------------------------------
             Calculate final location
            ------------------------------------------------------------------}


            NewX :=
                Board.XOrigin +
                MMsToCoord(
                    OriginXMM +
                    PX * PitchXMM
                );


            NewY :=
                Board.YOrigin +
                MMsToCoord(
                    OriginYMM +
                    PZ * PitchZMM
                );



            {------------------------------------------------------------------
             ONE COMPLETE TRANSACTION PER COMPONENT

             This is the method that worked without breaking selection.
            ------------------------------------------------------------------}


            PCBServer.PreProcess;


            Try


                PCBServer.SendMessageToRobots(
                    Comp.I_ObjectAddress,
                    c_Broadcast,
                    PCBM_BeginModify,
                    c_NoEventData
                );


                Try


                    {==========================================================
                     THE ONLY TWO COMPONENT PROPERTIES MODIFIED
                    ==========================================================}

                    Comp.X :=
                        NewX;

                    Comp.Y :=
                        NewY;


                Finally


                    PCBServer.SendMessageToRobots(
                        Comp.I_ObjectAddress,
                        c_Broadcast,
                        PCBM_EndModify,
                        c_NoEventData
                    );


                End;


            Finally


                PCBServer.PostProcess;


            End;


            MoveCount :=
                MoveCount + 1;


        End;



        {======================================================================
         REDRAW
        ======================================================================}


        Client.SendMessage(
            'PCB:Zoom',
            'Action=Redraw',
            255,
            Client.CurrentView
        );



        {======================================================================
         FINISHED
        ======================================================================}


        ShowMessage(
            'LED MATRIX PLACEMENT COMPLETE' +
            #13#10#13#10 +

            'LEDs moved: ' +
            IntToStr(MoveCount) +
            #13#10#13#10 +

            'Pitch X: ' +
            FloatToStr(PitchXMM) +
            ' mm' +
            #13#10 +

            'Pitch Z: ' +
            FloatToStr(PitchZMM) +
            ' mm' +
            #13#10#13#10 +

            'Center-to-center matrix span:' +
            #13#10 +

            'X = ' +
            FloatToStr(
                (MatrixXCount - 1) *
                PitchXMM
            ) +
            ' mm' +
            #13#10 +

            'Z = ' +
            FloatToStr(
                (MatrixZCount - 1) *
                PitchZMM
            ) +
            ' mm'
        );


    Finally


        MoveList.Free;

        CoordList.Free;


    End;

End;
