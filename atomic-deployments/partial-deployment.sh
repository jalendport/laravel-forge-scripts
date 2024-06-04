CONFIG_KEEP_RELEASES=10

FOLDER_DEPLOY_CACHE=$FORGE_SITE_PATH/deploy-cache
FOLDER_PERSISTENT=$FORGE_SITE_PATH/persistent
FOLDER_RELEASES=$FORGE_SITE_PATH/releases
FOLDER_DEPLOYING_RELEASE=$FOLDER_RELEASES/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID
FOLDER_LIVE_RELEASE=$FORGE_SITE_PATH/current

echo "Ensuring directories exist"
mkdir -p $FOLDER_DEPLOY_CACHE
mkdir -p $FOLDER_PERSISTENT
mkdir -p $FOLDER_RELEASES

if [ -d "$FOLDER_DEPLOYING_RELEASE" ];
then
	rm -rf $FOLDER_DEPLOYING_RELEASE
fi

echo "Creating \`releases/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID\`"
mkdir -p $FOLDER_DEPLOYING_RELEASE
cp -a $FOLDER_DEPLOY_CACHE/. $FOLDER_DEPLOYING_RELEASE/

echo "Symlinking persistent files & directories"
[ -f $FOLDER_PERSISTENT/.env ] && ln -nfs $FOLDER_PERSISTENT/.env $FOLDER_DEPLOYING_RELEASE
[ -d $FOLDER_PERSISTENT/data ] && ln -nfs $FOLDER_PERSISTENT/data/* $FOLDER_DEPLOYING_RELEASE/data/
[ -d $FOLDER_PERSISTENT/storage ] && ln -nfs $FOLDER_PERSISTENT/storage/* $FOLDER_DEPLOYING_RELEASE/storage/
[ -d $FOLDER_PERSISTENT/web/media ] && ln -nfs $FOLDER_PERSISTENT/web/media/* $FOLDER_DEPLOYING_RELEASE/web/media/
[ -d $FOLDER_PERSISTENT/web/cpresources ] && ln -nfs $FOLDER_PERSISTENT/web/cpresources $FOLDER_DEPLOYING_RELEASE/web/cpresources

echo "Symlinking \`current\` to \`releases/$FORGE_DEPLOY_COMMIT-$FORGE_DEPLOYMENT_ID\`"
rm -f $FOLDER_LIVE_RELEASE
ln -s $FOLDER_DEPLOYING_RELEASE $FOLDER_LIVE_RELEASE

( flock -w 10 9 || exit 1
	echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock

echo "Removing old releases"
cd $FOLDER_RELEASES
ls -t | tail -n +$((CONF_KEEP_RELEASES + 1)) | xargs rm -rf

echo "Done!"
