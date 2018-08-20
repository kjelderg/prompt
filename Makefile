J_NAME=scriptrunner
J_IP=127.0.1.99
J_PATH=/usr/jails/$(J_NAME)/

all: checkroot build install

checkroot: # The below does require root privileges or similar to create and control jails.
.if "${EUID}" == "0"
	@echo "This script must be run as root" 
	@exit 1
.endif

build:
	ezjail-admin create $(J_NAME) 'lo1|$(J_IP)'
	ezjail-admin start $(J_NAME)

# ezjails do not quite get network out-of-the-box in our configuration.
#  pf needs a reload to notice the new loopback alias
	service pf reload
#  what resolves for the hen is good for the gander
	cp /etc/resolv.conf $(J_PATH)etc/

install: # install and configure relevant packages
#  git - the exercise requires this be a git repo
#  HTTP::Daemon::SSL - the exercise requires serving scripts over https
	ASSUME_ALWAYS_YES=yes pkg -j $(J_NAME) install git p5-HTTP-Daemon-SSL

# configure git
	service sshd rcvar >> $(J_PATH)etc/rc.conf
	jexec $(J_NAME) pw useradd admin -s /usr/local/bin/git-shell -m
	mkdir -p $(J_PATH)git/certs $(J_PATH)git/webroot
	jexec $(J_NAME) chown admin /git/webroot
	jexec -U admin $(J_NAME) git init --bare /usr/home/admin/admin
	echo 'git --work-tree=/git/webroot/ --git-dir=/usr/home/admin/admin/ checkout -f' >> $(J_PATH)/usr/home/admin/admin/hooks/post-receive
	chmod a+x $(J_PATH)/usr/home/admin/admin/hooks/post-receive

# generate an SSH key set
	ssh-keygen -t rsa -f git.sshkey -q -N ''
	mkdir $(J_PATH)usr/home/admin/.ssh
	cp git.sshkey.pub $(J_PATH)usr/home/admin/.ssh/authorized_keys

#  generate self-signed ssl cert...openssl really has a messy convention here.
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout $(J_PATH)git/certs/server-key.pem -out $(J_PATH)git/certs/server-cert.pem -subj "/C=US/ST=GA/L=Atlanta/O=self/OU=self/CN=self"

# install the Web Server
	cp webserver $(J_PATH)git
	echo '/git/webserver &' > $(J_PATH)etc/rc.local

# bounce it once to make sure services come up properly on boot
	ezjail-admin restart $(J_NAME) 

clean: # get rid of the jail, the keys, and the local repository checkout
	ezjail-admin delete -fw $(J_NAME)
	rm git.sshkey git.sshkey.pub
	rm -rf admin

test: # initialize a repository and visually validate that the web request works.
	git init admin
	echo "date" > admin/date.sh
	echo "ps auxw" > admin/ps.sh
	chmod a+x admin/*.sh
	git -C admin add '*.sh'
	git -C admin commit -m 'test'
	git -C admin config core.sshCommand 'ssh -o UserKnownHostsFile=/dev/null -i ../git.sshkey'
	git -C admin remote add origin ssh://admin@$(J_IP)/~/admin
	git -C admin push origin master
	curl -k 'https://$(J_IP)'
