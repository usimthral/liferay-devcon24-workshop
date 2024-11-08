echo "Selected environment is $WORKSPACE_ENVIRONMENT"

COMMON_DIR="/configs/common"
ENV_DIR="/configs/$WORKSPACE_ENVIRONMENT"

echo "Note: Hidden files beginning with . will not be copied!"

if [ -d "$COMMON_DIR" ]; then

  if [ -z "$(ls $COMMON_DIR/)" ]; then
    echo "No environment specific files in $COMMON_DIR"
  else
    echo "Add common files from $COMMON_DIR"
    ls -l $COMMON_DIR
    cp -R $COMMON_DIR/* /etc/nginx/
  fi

else
  echo "Folder $COMMON_DIR for common files not found"
fi

if [ -d "$ENV_DIR" ]; then

  if [ -z "$(ls $ENV_DIR/)" ]; then
    echo "No environment specific files in $ENV_DIR"
  else
    echo "Add environment specific files from $ENV_DIR"
    ls -l $ENV_DIR
    cp -R $ENV_DIR/* /etc/nginx/
  fi

else
  echo "Folder $ENV_DIR for environment specific files not found"
fi