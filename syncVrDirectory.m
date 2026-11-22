function localDir = syncVrDirectory(vrDirectory)
% SYNCVRDIRECTORY Mirror a server VR environment folder to this rig and return the local copy.
%
%   localDir = syncVrDirectory(vrDirectory)
%
% Loading multi-frame tifs over the network is slow, so environments are read
% from a local mirror instead. The server folder stays the single source of
% truth: robocopy /MIR copies new or changed files and DELETES local files that
% are no longer on the server, so every rig holds exactly the server's set.
% Unchanged files are skipped (size + timestamp check), so a sync with no
% changes takes about a second.
%
% Settings keep the server path; only file reads use the local mirror.
% Local (non-UNC) directories are returned unchanged with no copying.
% If the server can't be reached, the existing mirror is used with a warning.

mirrorRoot = 'C:\vrEnvMirror';

localDir = vrDirectory;
if isempty(vrDirectory) || ~startsWith(vrDirectory, '\\'), return, end % not a server path

% One mirror folder per server folder, e.g. \\znas\Code\Hayley\vrEnv\ -> C:\vrEnvMirror\znas_Code_Hayley_vrEnv\
serverDir = regexprep(vrDirectory, '[\\/]+$', '');
localDir = [fullfile(mirrorRoot, regexprep(regexprep(serverDir, '^\\\\', ''), '[\\/:]+', '_')), filesep];

if exist(serverDir, 'dir')
    fprintf(1, 'Syncing VR environments from %s to %s ...\n', serverDir, localDir);
    syncTimer = tic;
    % /MIR mirror (incl. deletes), /LEV:1 top-level files only (the GUI never looks in
    % subfolders such as old\), /R:2 /W:2 short retries, /NP /NJH /NJS /NDL quieter output
    [status, out] = system(sprintf('robocopy "%s" "%s" /MIR /LEV:1 /R:2 /W:2 /NP /NJH /NJS /NDL', ...
        serverDir, localDir(1:end-1)));
    if status >= 8 % robocopy exit codes 0-7 are success, >=8 means something failed
        warning('syncVrDirectory:failed', ...
            'VR environment sync failed (robocopy code %d); local mirror may be out of date:\n%s', status, out);
    else
        copied = strtrim(out);
        if isempty(copied)
            fprintf(1, 'VR environments up to date (%.1fs).\n', toc(syncTimer));
        else
            fprintf(1, 'VR environments synced in %.1fs:\n%s\n', toc(syncTimer), copied);
        end
    end
elseif exist(localDir, 'dir')
    warning('syncVrDirectory:offline', ...
        'Cannot reach %s; using existing local mirror %s (may be out of date).', serverDir, localDir);
else
    warning('syncVrDirectory:missing', ...
        'Cannot reach %s and no local mirror exists.', serverDir);
end
end
