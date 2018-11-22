program ExportTEO;

uses
  Vcl.Forms,
  uTriwacoGrid,
  uError,
  Dutils,
  System.SysUtils,
  Vcl.Dialogs,
  eExportTEO in 'eExportTEO.pas' {MainForm};

var
  Initiated: Boolean;
  i, n, offset, clustNr, AqfrNr: Integer;
  f: TextFile;
  parPrefix, s, PARTRANS, PARCHGLIM, obsPrefix: String;
  initialvalue, minParvalue, maxParvalue: Double;
{$R *.res}

Procedure ShowArgumentsAndTerminate;
begin
  ShowMessage( 'ExportTEO inputFileName(*.teo) xy-outputFileName ' +
    '[parPrefix PARTRANS offset initialvalue minParvalue maxParvalue]' +
    ' or [chi-filename obsPrefix offset clustNr AqfrNr]' );
  Application.Terminate;
end;
begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);

  if not ( (ParamCount() = 2) or ( ParamCount() = 7 ) or ( ParamCount() = 8 ) )  then
     ShowArgumentsAndTerminate;

  MainForm.triwacoGrid1 := TTriwacoGrid.InitFromTextFile( ParamStr(1), MainForm, Initiated );

  with MainForm do begin
    with TriwacoGrid1 do begin
      n := NrOfNodes;

      // Write xy coordinates to be used for example in kriging (target points)
      AssignFile( f, ParamStr(2) ); Rewrite( f );
      for i := 1 to n do
        Writeln( f, i, ' ', XcoordinatesNodes[i]:10:2, ' ', YcoordinatesNodes[i]:10:2 );
      CloseFile( f );

      // Write optional files related to the use of pilot points inPEST
      if ParamCount = 8 then begin

        parPrefix := ParamStr( 3 ); //for example parPrefix = 'k'

       PARTRANS := LowerCase( ParamSTr( 4 ) ); //none, log, fixed or tied
       if not ( ( PARTRANS = 'none' ) or ( PARTRANS = 'log' )or
         ( PARTRANS = 'fixed' ) or( PARTRANS = 'tied' ) ) then
         ShowArgumentsAndTerminate;

        if PARTRANS = 'log' then
          PARCHGLIM := 'factor '
        else
          PARCHGLIM := 'relative';
        Try
          offset := StrToInt( ParamStr( 5 ) ); // Ususally 0
          initialvalue := StrToFloat( ParamStr( 6 ) );
          minParvalue := StrToFloat( ParamStr( 7 ) );
          maxParvalue := StrToFloat( ParamStr( 8 ) );
        Except
          ShowArgumentsAndTerminate;
        End;

        // Write Pilot Point file (*.pts)
        // Use this file to calculate interpolation factors with
        // calc_kriging_factors_2d() in plproc (PEST)
        AssignFile( f, parPrefix+'.pts' ); Rewrite( f );
        for i := 1 to n do
          //Write pilot point prefix, x, y, SLIST (=1), PLIST(=1.0)
          Writeln( f, 'ppt' + IntToStr( i + offset ) + ' ', XcoordinatesNodes[i]:10:2, ' ', YcoordinatesNodes[i]:10:2, ' 1  1.0 ' );
        CloseFile( f );

        // Write the template (*.tpl) of the pilot point file.
        AssignFile( f, parPrefix+'.tpl' ); Rewrite( f );
        Writeln( f, 'ptf $' );
        for i := 1 to n do begin
          //Write pilot point prefix, x, y, SLIST (=1), PLIST(=1.0)
          s :=  'ppt' + IntToStr( i + offset );
          Writeln( f, s + ' ',
            XcoordinatesNodes[i]:10:2, ' ', YcoordinatesNodes[i]:10:2,
            ' 1 $ ' + parPrefix + '_' + s + ' $' );
        end;
        CloseFile( f );

        //Prepare 'parameter data' section to be inserted into the *.pst file
        AssignFile( f, parPrefix+'.txt' ); Rewrite( f );
        // As a reminder to insert in model input/output section
        Writeln( f, '* parameter groups' );
        Writeln( f, parPrefix + '    relative    0.01  0.0  switch  2.0 parabolic' );
        Writeln( f, '* model input/output' );
        Writeln( f, parPrefix+'.tpl  ' + parPrefix+'.pts' );
        for i := 1 to n do begin
          s :=  parPrefix + '_' +'ppt' + IntToStr( i + offset );
          Writeln( f, Format( '%10-s %6-s %6-s %f %f %f %5-s 1.0  0.0  1',
            [s, partrans, PARCHGLIM, initialvalue, MinParValue, MaxParValue, parPrefix] ) );
        end;
        CloseFile( f );
        // end if write optional files related to the use of pilot points in PEST
      end else if ParamCount = 7 then begin
        //Append dummy observations to existing chi-file
        AssignFile( f, ParamStr(3) ); Append( f );
        obsPrefix := ParamStr( 4 ); //For example   obsPrefix='dmh' (like 'dummy head')
        offset := StrToInt( ParamStr( 5 ) ); // Ususally 0
        clustNr := StrToInt( ParamStr( 6 ) );
        AqfrNr := StrToInt( ParamStr( 7 ) );
        for i := 1 to n do begin
          s := obsPrefix + '_' + IntToStr( i + offset );
          Writeln( f, Format( '%10-s %9.1f %9.1f %4d %4d      0.00                0.00',
            [s, XcoordinatesNodes[i], YcoordinatesNodes[i], clustNr, AqfrNr] ) );
        end;
        CloseFile( f );
        //Append dummy observations to existing instruction (*.ins)-file
        AssignFile( f, ChangeFileExt( ParamStr(3), '.ins' ) ); append( f );
        for i := 1 to n do begin
          s := 'l1 (' + obsPrefix + '_' + IntToStr( i + offset ) + ')22:40';
          Writeln( f, s );
        end;
        CloseFile( f );
        //Create file with dummy observations to be inserted into the pest
        //control file (*.pst)
        AssignFile( f, 'DummyObservations.pst' ); Rewrite( f );
        for i := 1 to n do begin
          s := obsPrefix + '_' + IntToStr( i + offset );
          Writeln( f, Format( '%10-s            0.00          0.0 %10-s',
            [ s, obsPrefix] ) );
        end;
        Closefile( f )
      end;

    end; {-with TriwacoGrid1}
  end;

  {Application.Run;}
end.
