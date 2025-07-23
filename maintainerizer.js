const path = require('path');
const fs = require('fs');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec)

async function TurnOnGitMaintenance(path) {
  let configOutput;
  try{
    configOutput = await exec('git maintenance start', {
      cwd: path,
      shell: isWin ? 'C:\\Program Files\\Git\\bin\\bash.exe' : 'bash',
      windowsHide: true,
     });
  } catch (e) {
    console.error(e);
  }
  return configOutput?.stdout?.trim();
};

async function ListGitMaintenanceRepos(path) {
    let result;
    try{
      result = await exec('git config --global --get-all maintenance.repo', {
        cwd: path,
        shell: isWin ? 'C:\\Program Files\\Git\\bin\\bash.exe' : 'bash',
        windowsHide: true,
       });
    } catch (e) {
      console.error(e);
    }
    return result?.stdout?.trim();
  };

var args = process.argv.slice(2);
var directoryPath = args[0] || __dirname;
var isWin = process.platform === "win32";

fs.readdir(directoryPath, {withFileTypes: true}, async (err, entries) => {
    tape();
    if (err) {
        return console.log('Sorry, friend. Unable to scan directory: ' + err);
    }
    const directories = entries
        .filter(dirent => dirent.isDirectory())
        .filter(d => d.name.indexOf('$RECYCLE') === -1)
        .filter(d => d.name.indexOf('.nuget') === -1)
        .filter(d => d.name.indexOf('System Volume Information') === -1);
                
    directories.forEach(async dirent => {
        const _path = path.join(directoryPath, dirent.name);
        console.log(`[Turning on maintenance for]: ${dirent.name}; ${_path}`);
        try{
            await TurnOnGitMaintenance(_path);
        } catch (e) {
            console.error(e);
        }
    });

    console.log('Repos under maintenance: ');
    const result = await ListGitMaintenanceRepos(path.join(directoryPath));
    console.log(result);
});

const tape = () => {
console.log(' __________________________________________ ');
console.log('|  _______________________________________ |');
console.log('| / .-----------------------------------. \ |');
console.log('| | | /\\ :                       90 min| | |');
console.log('| | |/--\\:...................... NR [ ]| | |');
console.log('| | `-----------------------------------\'| |');
console.log('| |      //-\\\\   |         |   //-\\\\     | |');
console.log('| |     ||( )||  |_________|  ||( )||    | |');
console.log('| |      \\\\-//   :....:....:   \\\\-//     | |');
console.log('| |       _ _ ._  _ _ .__|_ _.._  _      | |');
console.log('| |      (_(_)| |(_(/_|  |_(_||_)(/_     | |');
console.log('| |               low noise   |          | |');
console.log('| `______ ____________________ ____ _____\' |');
console.log('|        /    []             []   \\        |');
console.log('|       /  ()                   () \\       |');
console.log('!______/____________________________\\______!');
console.log('                                             ');
};
