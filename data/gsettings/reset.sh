# Resets Terminio settings to default for testing purposes
gsettings list-schemas | grep Terminio | xargs -n 1 gsettings reset-recursively
dconf list /io/github/maragkose/Terminio/profiles/ | xargs -I {} dconf reset -f "/io/github/maragkose/Terminio/profiles/"{}
