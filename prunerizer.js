const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');


var args = process.argv.slice(2);
var directoryPath = args[0] || __dirname;

fs.readdir(directoryPath, {withFileTypes: true}, (err, entries) => {
    anon();
    if (err) {
        return console.log('Sorry, friend. Unable to scan directory: ' + err);
    }
    const directories = entries
        .filter(dirent => dirent.isDirectory())
        .filter(d => d.name.indexOf('$RECYCLE') === -1)
        .filter(d => d.name.indexOf('System Volume Information') === -1);

    directories.forEach(dirent => {
         const command = `shopt -s expand_aliases \n
            . ~/.bashrc \n
	    pwd \n
            git checkout $(git rev-parse --abbrev-ref origin/HEAD | cut -c8-) \n
            git pull \n
	        git branch -av \n
            git remote prune origin \n 
            set -x \n
            gbpurge \n
            # rmgone`
            ;
         const _path = path.join(directoryPath, dirent.name);
         console.log(`Purging: ${dirent.name}; ${_path}`);
         exec(command, {
             cwd: _path,
             shell: 'C:\\Program Files\\Git\\bin\\bash.exe',
             windowsHide: true,
            }, (error, stdout, stderr) => console.log(error?.message || stdout));
        });
});

const anon = () => {
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
};
