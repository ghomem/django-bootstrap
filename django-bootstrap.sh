#!/bin/bash

### BEGIN CUSTOMIZE THIS ###

# no dashes allowed
DJANGO_PROJNAME=djangoproject
DJANGO_APPNAME=djangoapp
DJANGO_HOMEDIR=/var/opt/django
DJANGO_USERNAME=django

DJANGO_SUPERUSER_USERNAME=djadmin
DJANGO_SUPERUSER_EMAIL=root@localhost.local
DJANGO_SUPERUSER_PASSWORD=$(makepasswd)

### END CUSTOMIZE THIS ###

E_OK=0
E_ERR=1

DJANGO_PACKAGES="python3-django python3-djangorestframework python3-psycopg2 gunicorn postgresql-client vim makepasswd"
SRC_DIR=./src

function handle_error () {
    rc=$1
    err_message=$2

    if [ "0" != "$rc" ]; then
        echo $err_message
        exit $rc
    fi
}

function print_output () {

  echo
  echo "Project is at $DJANGO_HOMEDIR/$DJANGO_PROJNAME"
  echo "App is at $DJANGO_HOMEDIR/$DJANGO_PROJNAME/$DJANGO_APPNAME"
  echo
  echo "Important paths for customization"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_PROJNAME/templates"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_PROJNAME/static"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_PROJNAME/$DJANGO_PROJNAME/settings.py"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_APPNAME/views.py"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_APPNAME/models.py"
  echo "  * $DJANGO_HOMEDIR/$DJANGO_APPNAME/urls.py"
  echo
  echo "You can now start the application with:"
  echo "  sudo su - $DJANGO_USERNAME python3 -c \"$DJANGO_HOMEDIR/$DJANGO_PROJNAME/manage.py runserver\""
  echo
  echo "The following URLs will be available:"
  echo "  * App URL:   http://127.0.0.1:8000/$DJANGO_APPNAME"
  echo "  * Admin URL: http://127.0.0.1:8000/admin"
  echo
  echo "To make these URLS available in your browser you can simply forward them with:"
  echo "  ssh -L 8000:127.0.0.1:8000 USERNAME@REMOTEIP"
  echo
  echo "You can remove all Django related configuration with:"
  echo "  sudo userdel -r $DJANGO_USERNAME"
  echo "and restart the configuration process, if necessary."
  echo
  echo "You can pack the application with:"
  echo "  sudo tar -C $DJANGO_HOMEDIR/ --exclude=\"*__pycache__*\" --exclude=\*db.sqlite3\* -zcf /tmp/$DJANGO_PROJNAME.tar.gz $DJANGO_PROJNAME"
  echo

}
### Main script ###

my_id=$(id -u)

test $my_id -eq 0
handle_error $? "Please run this script as root."

echo "Installing Django related packages"
apt-get install -y -q=2 $DJANGO_PACKAGES &> /dev/null
handle_error $? "Error installing packages"

echo "Creating user $DJANGO_USERNAME for Django execution"
echo
adduser --system --home=$DJANGO_HOMEDIR --disabled-password --group --shell=/bin/bash $DJANGO_USERNAME
handle_error $? "Error adding user $DJANGO_USERNAME"

echo
echo "Creating project $DJANGO_PROJNAME"
sudo su - $DJANGO_USERNAME -c "django-admin startproject $DJANGO_PROJNAME"
handle_error $? "Error creating project $DJANGO_PROJNAME"

echo "Creating app $DJANGO_APPNAME inside project $DJANGO_PROJNAME"
sudo su - $DJANGO_USERNAME -c "cd $DJANGO_HOMEDIR/$DJANGO_PROJNAME; python3 manage.py startapp $DJANGO_APPNAME"
handle_error $? "Error creating app $DJANGO_APPNAME inside project $DJANGO_PROJNAME"

echo "Creating project structure"

# copying application custom files
for src_file in urls.py views.py; do
  cp -f $SRC_DIR/app/$src_file $DJANGO_HOMEDIR/$DJANGO_PROJNAME/$DJANGO_APPNAME/
done

# copying project custom files
for src_file in urls.py settings.py; do
  cp -f $SRC_DIR/proj/$src_file $DJANGO_HOMEDIR/$DJANGO_PROJNAME/$DJANGO_PROJNAME
done

mkdir -p $DJANGO_HOMEDIR/$DJANGO_PROJNAME/templates/registration

for src_file in base.html toplevel.html index.html registration/login.html; do
  cp -f $src_file $DJANGO_HOMEDIR/$DJANGO_PROJNAME/templates/$src_file
done

for static_dir in img css js; do
  mkdir -p $DJANGO_HOMEDIR/$DJANGO_PROJNAME/static/$static_dir
done

# set the custom app name on installed files
for installed_file in $DJANGO_PROJNAME/urls.py $DJANGO_PROJNAME/settings.py $DJANGO_APPNAME/urls.py; do
  sed -i "s/DJANGO_APPNAME/$DJANGO_APPNAME/g" $DJANGO_HOMEDIR/$DJANGO_PROJNAME/$installed_file
done

# create the tables for the default installed apps on the database
echo
sudo su - $DJANGO_USERNAME -c "cd $DJANGO_HOMEDIR/$DJANGO_PROJNAME; python3 manage.py migrate"
handle_error $? "Error migrating database tables"

# creating superuser
echo
sudo su - $DJANGO_USERNAME -c "cd $DJANGO_HOMEDIR/$DJANGO_PROJNAME; DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD python3 manage.py createsuperuser --no-input --username $DJANGO_SUPERUSER_USERNAME --email $DJANGO_SUPERUSER_EMAIL"
handle_error $? "Error migrating superuser $DJANGO_SUPERUSER_USERNAME"

echo "  * username is $DJANGO_SUPERUSER_USERNAME"
echo "  * password is $DJANGO_SUPERUSER_PASSWORD"

# print user friendly output
print_output
