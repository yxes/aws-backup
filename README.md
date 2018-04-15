# aws-backup
_bash scripts to automatically backup my ec2 instances (snapshot of volumes and AMIs)_

## INSTALLATION & USAGE

I've only ever used this on _UBUNTU_ Linux, your milage may vary if you are on something else

### Ensure you have the latest version of Java

Follow whatever is easiest for you from this page

https://thishosting.rocks/install-java-ubuntu/

in the end you need to be able to type: `java -version` and get something like this

```
$ java -version
openjdk version "1.8.0_162"
OpenJDK Runtime Environment (build 1.8.0_162-8u162-b12-0ubuntu0.16.04.2-b12)
OpenJDK 64-Bit Server VM (build 25.162-b12, mixed mode)
```

### EC2 CLI Files

download and install the command line files according to the following

https://kb.novaordis.com/index.php/Amazon_EC2_CLI_Installation


#### Establish EC2 Config File (Post-Install Section)

When you are setting up your config file in the post-install portion instead of updating your `.bashrc` file it's much cleaner to create a `~/.ec2` file with the following:

```
# Basic EC2 Env Vars
export AWS_ACCESS_KEY="XXXXXXXXX"
export AWS_SECRET_KEY="XXXXXXXXXXXXXXXXX"
export EC2_HOME="/opt/ec2-api-tools"
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre"
export PATH="$PATH:$EC2_HOME/bin"
export EC2_URL=https://ec2.XXXXXXXXX.amazonaws.com
```

the **ACCESS** and **SECRET KEY**'s are available from [API Access Keys](https://kb.novaordis.com/index.php/Amazon_AWS_Security_Concepts#API_Access_Keys) 

The **EC2_URL** requires your region i.e. `us-west-2` or `us-east-1` for instance.

Next secure it with `chmod 600 ~/.ec2` and add the following to end of the your `~/.bashrc` file:

```
# EC2 Command
source /home/ubuntu/.ec2
```

The `backup-vol.sh` and `create-ami.sh` files know to look for the `~/.ec2` file in case you're not logged in when they run.

When you're done setting these up login using another window and test your installation works by entering

`/opt/ec2-api-tools/bin/ec2-describe-regions`

if it works you can continue...

### Create AMI - configuration

I'm very lazy so I just copy the `create-ami.sh` file into `~/bin` and rename it to my server name. As an example, let's say my server name is **ODIN**. Here's how to setup **ODIN**

`cp create-ami.sh ~/bin/create-odin-ami.sh`

then edit the shell file `vi ~/bin/create-odin-ami.sh` (or whatever editor you want of course)

look for **INSTANCE_NAME** and **INSTANCE_ID** and set them to be **ODIN** and the **instance id** you find associated with your ec2 server when looking at the list on AWS. (I assume you know how to do that)

while you're in there decide how many AMIs you want to keep on hand (the default is 2). If you want more, just change MAX_AMIS. Old AMIs are deleted with OLD meaning more than the number of the AMIs (not by date).

make your shell script executable `chmod 755 ~/bin/create-odin-ami.sh` and add it to cron so it backs up periodically.

`crontab -e` 

Here's a weekly entry (_2:15am Tuesdays_):

```
# Weekly AMIs - Mondays nights / Tuesday mornings
15    2  * * 2 /home/ubuntu/bin/create_ami-odin.sh >/dev/null 2>&1
```

### Backup Vol - configuration

Use the same method for backing up individual volumes as you would Createing AMIs. When you create an AMI it backs up the volume as well, however I tend to have information that I need backed up more frequently in these cases. The AMI gives you the full server, whereas the volume only takes on a specific drive. My websites are housed on a specific drive, so I back that up more frequently (separately) than I would the server using an AMI.

## CONTRIBUTING

You are welcome to fork this repository and updates, fixes, etc are strongly
encouraged.

[how to contribute](https://help.github.com/articles/setting-guidelines-for-repository-contributors/)

## LICENSE

The contents of this repository are covered under the [MIT License](https://github.com/udacity/ud777-writing-readmes/blob/master/LICENSE)

## Author

Originally created by [Steve Wells](https://www.stephendwells.com/)