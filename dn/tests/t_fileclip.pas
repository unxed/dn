program t_fileclip;
{ Tests of src/fileclip.pas: URI-list and Windows file-drop conversion. }
{$mode objfpc}{$H+}
uses SysUtils, FileClip;
{$I dntest.inc}

var
  P, Q: TFileClipPaths;
  Uri, Err: AnsiString;
  Drop: UnicodeString;
begin
  SetLength(P, 2);
  P[0] := '/tmp/a b#%';
  P[1] := '/tmp/' + UnicodeString(#$00E9);
  Check(FileClipPathsToUriList(P, Uri, Err), 'absolute POSIX paths become a URI list');
  Check(Uri = 'file:///tmp/a%20b%23%25' + #13#10 + 'file:///tmp/%C3%A9' + #13#10,
    'spaces, reserved bytes and UTF-8 are encoded with CRLF');
  Check(FileClipUriListToPaths(Uri, Q, Err) and (Length(Q) = 2) and (Q[0] = P[0]) and (Q[1] = P[1]),
    'encoded paths round trip in order');

  Check(FileClipUriListToPaths('# comment' + #10 + #10 + 'file:///one' + #10 + 'file:///two' + #10, Q, Err) and
    (Length(Q) = 2) and (Q[0] = '/one') and (Q[1] = '/two'), 'LF, blank lines and comments are accepted');
  Check(FileClipUriListToPaths('file:///one' + #13#10 + 'file:///two' + #13#10, Q, Err) and
    (Length(Q) = 2) and (Q[1] = '/two'), 'CRLF input is accepted');
  SetLength(P, 0);
  Check(FileClipPathsToUriList(P, Uri, Err) and (Uri = ''), 'an empty path list is an empty URI list');

  SetLength(P, 3);
  P[0] := 'C:\';
  P[1] := 'D:\folder with space';
  P[2] := '\\server\share\file';
  Check(FileClipPathsToUriList(P, Uri, Err) and
    (Uri = 'file:///C:/' + #13#10 + 'file:///D:/folder%20with%20space' + #13#10 +
      'file://server/share/file' + #13#10), 'drive roots and UNC paths become file URIs');
  Check(FileClipUriListToPaths(Uri, Q, Err) and (Length(Q) = 3) and
    (Q[0] = 'C:\') and (Q[1] = 'D:\folder with space') and (Q[2] = '\\server\share\file'),
    'drive roots and UNC paths round trip');
  Check(not FileClipUriListToPaths('file:///bad%Q0', Q, Err) and (Length(Q) = 0), 'bad percent escapes are rejected');
  Check(not FileClipUriListToPaths('file:relative', Q, Err), 'relative file URIs are rejected');
  Check(FileClipUriListToPaths('file://localhost/tmp/file', Q, Err) and (Length(Q) = 1) and
    (Q[0] = '/tmp/file'), 'localhost is a local file authority');
  Check(FileClipUriListToPaths('file://localhost/C:/file', Q, Err) and (Q[0] = 'C:\file'),
    'localhost drive URIs are decoded as Windows paths');
  Check(not FileClipUriListToPaths('https://host/file', Q, Err), 'non-file schemes are rejected');
  Check(not FileClipUriListToPaths('file://server', Q, Err), 'a non-local authority without a share is rejected');
  SetLength(P, 1);
  P[0] := 'relative';
  Check(not FileClipPathsToUriList(P, Uri, Err) and (Uri = ''), 'relative paths are rejected');

  SetLength(P, 3);
  P[0] := 'C:\';
  P[1] := 'D:\folder with space';
  P[2] := '\\server\share\file';
  Check(FileClipPathsToDrop(P, Drop, Err) and (Length(Drop) > 1) and (Drop[Length(Drop)] = #0) and
    (Drop[Length(Drop) - 1] = #0), 'CF_HDROP is a UTF-16 list with a double NUL terminator');
  Check(FileClipDropToPaths(Drop, Q, Err) and (Length(Q) = 3) and (Q[0] = P[0]) and
    (Q[1] = P[1]) and (Q[2] = P[2]), 'CF_HDROP preserves paths and order');
  SetLength(P, 0);
  Check(FileClipPathsToDrop(P, Drop, Err) and (Drop = #0#0), 'an empty CF_HDROP list has two NULs');
  Check(not FileClipDropToPaths('C:\file' + #0, Q, Err) and (Length(Q) = 0), 'a truncated CF_HDROP list is rejected');
  Check(not FileClipDropToPaths('relative' + #0#0, Q, Err), 'relative CF_HDROP paths are rejected');
  Check(not FileClipDropToPaths('C:\file' + #0 + #0 + 'extra', Q, Err), 'data after the CF_HDROP terminator is rejected');

  Finish;
end.
