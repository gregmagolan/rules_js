const {mkdirSync, copyFileSync, readdirSync, readFileSync, existsSync, statSync} = require('fs');
const path = require("path")
const {spawnSync} = require("child_process");

const packageDir = process.argv[2];
const postinstallDir = process.argv[3];

copyPackageContents(packageDir, postinstallDir);

const packageJson = JSON.parse(readFileSync(path.join(packageDir, "package.json")));

const postinstallScript = packageJson.scripts?.postinstall;

if (postinstallScript) {
    runPostinstall(postinstallScript, postinstallDir);
}

// Run a postinstall script in an npm package
function runPostinstall(script, packageDir) {
    const tokens = script.split(" ");
    const cmd = tokens[0];
    const args = tokens.slice(1);

    spawnSync(cmd, args, {cwd: packageDir, stdio: "inherit"});
}

// Copy contents of a package dir to a destination dir (without copying the package dir itself)
function copyPackageContents(packageDir, destDir) {
    readdirSync(packageDir).forEach(file => {
        copyRecursiveSync(path.join(packageDir, file), path.join(destDir, file));
    });
};

// Recursively copy files and folders
function copyRecursiveSync(src, dest) {
    const stats = statSync(src);
    if (stats.isDirectory()) {
        try {
            mkdirSync(dest);
        } catch (error) {
            if (error.code !== "EEXIST") {
                throw error;
            }
        }
        readdirSync(src).forEach(function(fileName) {
            copyRecursiveSync(path.join(src, fileName), path.join(dest, fileName));
        });
    } else {
        try {
            copyFileSync(src, dest);
        } catch (error) {
            if (error.code !== "EEXIST") {
                throw error;
            }
        }
    }
}