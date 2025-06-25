#######################################
############## CONFIG #################
#######################################

# CONFIG_DEPLOYMENT_TYPE: Sets deployment strategy
#   'partial'  - External CI/CD handles build steps, final files rsync'd to `deploy-cache`
#   'complete' - Server performs git pull to `deploy-cache` and runs composer install locally
CONFIG_DEPLOYMENT_TYPE="partial"

# CONFIG_KEEP_RELEASES: Number of previous deployments to retain before cleanup
#   Default: 5 releases
CONFIG_KEEP_RELEASES=5

# CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT: Specifies script from composer.json to run after deployment
#   Example: "craft-update" will execute the "craft-update" script defined in composer.json
CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT="craft-update"

# CONFIG_PERSISTENT_FILES: Array of files to preserve between deployments
#   These files will be symlinked from shared directory to each release
#   Common examples: .env files, license keys, etc.
CONFIG_PERSISTENT_FILES=(
	".env"
)

# CONFIG_PERSISTENT_DIRECTORIES: Array of directories to preserve between deployments
#   These directories will be symlinked from shared directory to each release
#   Typically contains user uploads, cache, and other runtime data
CONFIG_PERSISTENT_DIRECTORIES=(
	"storage"
	"web/cpresources"
)

#######################################
############ END CONFIG ###############
#######################################

FOLDER_DEPLOY_CACHE=$FORGE_SITE_PATH/deploy-cache
FOLDER_PERSISTENT=$FORGE_SITE_PATH/persistent
FOLDER_RELEASES=$FORGE_SITE_PATH/releases
FOLDER_DEPLOYING_RELEASE=$FOLDER_RELEASES/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID
FOLDER_LIVE_RELEASE=$FORGE_SITE_PATH/current

if [ -d "$FORGE_SITE_PATH/.git" ]; then
	echo "Moving git metadata to temporary location"
	mv "$FORGE_SITE_PATH/.git" "/tmp/.git-$FORGE_SITE_ID"
	echo "Removing remaining files from site path"
	rm -rf -- "$FORGE_SITE_PATH"/* "$FORGE_SITE_PATH"/.[^.]*
fi

echo "Ensuring directories exist"
mkdir -p $FOLDER_DEPLOY_CACHE
mkdir -p $FOLDER_PERSISTENT
mkdir -p $FOLDER_RELEASES

if [ -d "/tmp/.git-$FORGE_SITE_ID" ]; then
	echo "Moving git metadata from temporary location to `persistent`"
	mv "/tmp/.git-$FORGE_SITE_ID" "$FOLDER_PERSISTENT/.git-$FORGE_SITE_ID"
fi

if [ "$CONFIG_DEPLOYMENT_TYPE" = "complete" ]; then
	if [ ! -d "$FOLDER_DEPLOY_CACHE/.git" ] && [ -d "$FOLDER_PERSISTENT/.git-$FORGE_SITE_ID" ]; then
		echo "Copying git metadata from `persistent` to `deploy-cache`"
		cp -a "$FOLDER_PERSISTENT/.git-$FORGE_SITE_ID" "$FOLDER_DEPLOY_CACHE/.git"
	fi

	if [ -d "$FOLDER_DEPLOY_CACHE/.git" ]; then
		echo "Pulling latest changes from repo"
		cd $FOLDER_DEPLOY_CACHE && git pull origin $FORGE_SITE_BRANCH
	else
		echo "Warning: No git metadata found for pulling changes"
	fi
fi

if [ -d "$FOLDER_DEPLOYING_RELEASE" ];
then
	rm -rf $FOLDER_DEPLOYING_RELEASE
fi

echo "Creating \`releases/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID\`"
mkdir -p $FOLDER_DEPLOYING_RELEASE
cp -a $FOLDER_DEPLOY_CACHE/. $FOLDER_DEPLOYING_RELEASE/

echo "Symlinking persistent files & directories"
files=()
for file in "${CONFIG_PERSISTENT_FILES[@]}"; do
	files+=("$FOLDER_PERSISTENT/$file:$FOLDER_DEPLOYING_RELEASE/$file")
done
directories=()
for dir in "${CONFIG_PERSISTENT_DIRECTORIES[@]}"; do
	directories+=("$FOLDER_PERSISTENT/$dir:$FOLDER_DEPLOYING_RELEASE/$dir")
done
for file in "${files[@]}"; do
	source="${file%%:*}"
	target="${file#*:}"
	mkdir -p "$(dirname "$source")"
	touch "$source"
	rm -rf "$target" && ln -nfs "$source" "$target"
done
for dir in "${directories[@]}"; do
	source="${dir%%:*}"
	target="${dir#*:}"
	mkdir -p "$source"
	rm -rf "$target" && ln -nfs "$source" "$target"
done

if [ "$CONFIG_DEPLOYMENT_TYPE" = "complete" ]; then
	echo "Running composer install"
	cd $FOLDER_DEPLOYING_RELEASE
	$FORGE_COMPOSER install --no-ansi --no-dev --no-interaction --no-progress --no-scripts --optimize-autoloader
fi

echo "Symlinking \`current\` to \`releases/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID\`"
rm -f $FOLDER_LIVE_RELEASE
ln -s $FOLDER_DEPLOYING_RELEASE $FOLDER_LIVE_RELEASE

if [ -n "$CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT" ]; then
	echo "Running post-deployment script: $CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT"
	cd $FOLDER_LIVE_RELEASE
	$FORGE_COMPOSER run-script $CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT
fi

( flock -w 10 9 || exit 1
	echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock

echo "Removing old releases"
cd $FOLDER_RELEASES
ls -t | tail -n +$((CONFIG_KEEP_RELEASES + 1)) | xargs rm -rf

echo "Done!"
