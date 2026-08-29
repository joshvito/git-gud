const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');


var args = process.argv.slice(2);
var directoryPath = args[0] || process.cwd();

var isWin = process.platform === "win32";

// Returns true if `repoPath` is the root of a git repo (has a `.git` entry).
const isGitRepo = (repoPath) => fs.existsSync(path.join(repoPath, '.git'));

// Prune a single git repo: sync to origin's default branch and purge stale
// branches. `label` is just what we show in the logs.
const pruneRepo = (repoPath, label) => {
    // Skip reparse points (OneDrive placeholders, junctions, symlinks) —
    // they can't be used as a process cwd and surface as `spawn UNKNOWN`.
    try {
        if (fs.lstatSync(repoPath).isSymbolicLink()) {
            console.log(`Skipping (symlink/reparse point): ${label}`);
            return;
        }
    } catch (e) {
        console.log(`Skipping (cannot stat): ${label} — ${e.code}`);
        return;
    }

    const command = `shopt -s expand_aliases \n
        . ~/.bashrc \n
        pwd \n
        git checkout $(git rev-parse --abbrev-ref origin/HEAD | cut -c8-) \n
        git pull \n
        git branch -av \n
        git remote prune origin \n
        set -x \n
        gbpurge \n
        rmgone`;

    console.log(`Purging: ${label}; ${repoPath}`);
    // Run serially (execSync) so output stays readable and we don't spawn a
    // burst of processes that endpoint security may block. Isolate failures
    // so one bad repo can't take down the whole run.
    try {
        const stdout = execSync(command, {
            cwd: repoPath,
            shell: isWin ? 'C:\\Program Files\\Git\\bin\\bash.exe' : 'bash',
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
        });
        console.log(stdout.toString());
    } catch (error) {
        console.error(`FAILED in ${label} (${repoPath}): ${error.code || ''} ${error.message}`);
        if (error.stdout) console.log(error.stdout.toString());
        if (error.stderr) console.error(error.stderr.toString());
    }
};

anon();

// If we were pointed at a git repo directly, just prune that one repo.
// Otherwise treat the target as a container of repos and prune each subdir.
if (isGitRepo(directoryPath)) {
    pruneRepo(directoryPath, path.basename(path.resolve(directoryPath)));
} else {
    fs.readdir(directoryPath, {withFileTypes: true}, (err, entries) => {
        if (err) {
            return console.log('Sorry, friend. Unable to scan directory: ' + err);
        }
        const directories = entries
            .filter(dirent => dirent.isDirectory())
            .filter(d => d.name.indexOf('$RECYCLE') === -1)
            .filter(d => d.name.indexOf('System Volume Information') === -1);

        directories.forEach(dirent => {
            const _path = path.join(directoryPath, dirent.name);

            // ✅ Skip non-git directories
            if (!isGitRepo(_path)) {
                console.log(`Skipping (not a git repo): ${dirent.name}`);
                return;
            }

            pruneRepo(_path, dirent.name);
        });
    });
}

function anon() {
    console.log('                                    ████████████████                                    ');
    console.log('                              ██████░░░░░░░░░░░░░░░░██████                              ');
    console.log('░░      ░░      ░░          ██░░░░░░                ░░░░░░██              ░░      ░░  ░░');
    console.log('                      ░░  ██░░                            ░░██    ░░                    ');
    console.log('                        ██░░                                ░░██                        ');
    console.log('                        ██    ██████                ██████    ██                        ');
    console.log('                        ██  ░░░░░░░░████        ████░░░░░░░░  ██                        ');
    console.log('                        ██          ░░████    ████░░          ██                        ');
    console.log('                        ██            ░░░░    ░░░░            ██                        ');
    console.log('                        ██░░  ░░██████░░░░    ░░░░██████░░  ░░██                        ');
    console.log('                        ██░░░░██████████░░    ░░██████████░░░░██                        ');
    console.log('                        ██░░  ░░░░░░░░  ░░    ░░  ░░░░░░░░  ░░██                        ');
    console.log('                        ██              ░░    ░░              ██                        ');
    console.log('                        ██  ░░░░░░      ░░    ░░      ░░░░░░  ██                        ');
    console.log('                        ██  ░░░░░░    ░░        ░░    ░░░░░░  ██                        ');
    console.log('                        ██░░          ░░        ░░          ░░██                        ');
    console.log('                        ██░░░░██        ██░░░░██        ██░░░░██                        ');
    console.log('                        ██░░  ██████░░████████████░░██████  ░░██                        ');
    console.log('                        ██  ░░  ██████████    ██████████  ░░  ██                        ');
    console.log('                          ██  ░░░░    ░░░░░░░░░░░░    ░░░░  ██                          ');
    console.log('                          ██      ░░                ░░      ██                          ');
    console.log('                            ██  ░░  ░░░░░░████░░░░░░  ░░  ██                            ');
    console.log('                            ██░░  ░░      ████      ░░  ░░██                            ');
    console.log('                              ██░░      ░░████░░      ░░██                              ');
    console.log('                                ██░░    ░░████░░    ░░██                                ');
    console.log('                                  ██░░░░  ████  ░░░░██                                  ');
    console.log('                                    ████░░████░░████                                    ');
    console.log('                                        ████████                                        ');
    console.log('░░░░░░░░░░░░░░  ░░░░░░░░░░░░░░░░░░░░░░  ░░▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ░░░░░░');
}
