.PHONY: vm vagrant clean clean-all

all: vm

vm: playbook.yml Vagrantfile vagrant
	sleep 5
	ansible-playbook -u vagrant \
									 --extra-vars "domain=cbrgm.vnet" \
									 --private-key ./.vagrant/machines/default/virtualbox/private_key \
									 -e "ansible_python_interpreter=/usr/bin/python3" \
									 playbook.yml

vagrant:
	vagrant up

clean:
	rm -f *.retry

clean-vm:
	vagrant destroy -f
	ssh-keygen -f "/home/chris/.ssh/known_hosts" -R "10.0.30.10"

clean-all: clean clean-vm
