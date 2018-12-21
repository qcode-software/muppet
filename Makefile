NAME=muppet
RELEASE=0
MAINTAINER=hackers@qcode.co.uk
REMOTEUSER_LEGACY=debian.qcode.co.uk
REMOTEHOST_LEGACY=debian.qcode.co.uk
REMOTEDIR_LEGACY=debian.qcode.co.uk
REMOTEUSER=deb
REMOTEHOST=deb.qcode.co.uk
REMOTEDIR=deb.qcode.co.uk

define POSTINSTALL
#!/bin/bash
ln -sfT /usr/local/bin/muppet-${VERSION} /usr/local/bin/muppet
chmod 655 /usr/local/bin/muppet-${VERSION}
ln -sfT /etc/muppet-${VERSION}.tcl.sample /etc/muppet.tcl.sample
endef
export POSTINSTALL

.PHONY: all test package

all: test package upload clean
package: check-version
	rm -rf package
	mkdir package
	curl --fail -K ~/.curlrc_github -L -o v$(VERSION).tar.gz https://api.github.com/repos/qcode-software/muppet/tarball/v$(VERSION)
	tar --strip-components=1 --exclude Makefile --exclude description-pak --exclude muppet.tcl.conf --exclude doc --exclude package.tcl --exclude test --exclude test_all.tcl -xzvf v$(VERSION).tar.gz -C package
	./package.tcl package ${NAME} ${VERSION}
	./pkg_mkIndex package
	@echo "$$POSTINSTALL" > ./postinstall-pak
	fakeroot checkinstall -D --deldoc --backup=no --install=no --pkgname=$(NAME)-$(VERSION) --pkgversion=$(VERSION) --pkgrelease=$(RELEASE) -A all -y --maintainer $(MAINTAINER) --pkglicense="BSD" --reset-uids=yes --requires "tcl8.5,tcllib,qcode-tcl-8.20.0,iproute,tdom" --replaces none --conflicts none make local-install

tcl-package: check-version
	rm -rf package
	mkdir package
	./package.tcl package ${NAME} ${VERSION}
	./pkg_mkIndex package

test:   tcl-package 
	tclsh ./test_all.tcl -testdir test
	rm -rf package

install: tcl-package local-install

local-install: check-version
	mkdir -p /usr/lib/tcltk/$(NAME)$(VERSION)
	rm -f /usr/lib/tcltk/$(NAME)$(VERSION)/*
	cp package/*.tcl /usr/lib/tcltk/$(NAME)$(VERSION)/
	cp LICENSE /usr/lib/tcltk/$(NAME)$(VERSION)/
	cp bin/muppet /usr/local/bin/muppet-$(VERSION)
	cp muppet.tcl.conf /etc/muppet-$(VERSION).tcl.sample
	rm -rf package

upload: check-version
	scp $(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb "$(REMOTEUSER_LEGACY)@$(REMOTEHOST_LEGACY):$(REMOTEDIR_LEGACY)/debs"	
	ssh $(REMOTEUSER_LEGACY)@$(REMOTEHOST_LEGACY) reprepro -b $(REMOTEDIR_LEGACY) includedeb jessie $(REMOTEDIR_LEGACY)/debs/$(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb
	scp $(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb "$(REMOTEUSER)@$(REMOTEHOST):$(REMOTEDIR)/debs"	
	ssh $(REMOTEUSER)@$(REMOTEHOST) reprepro -b $(REMOTEDIR) includedeb stretch $(REMOTEDIR)/debs/$(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb

clean:  check-version
	rm -f $(NAME)-$(VERSION)_$(VERSION)-$(RELEASE)_all.deb
	rm -rf package
	rm -f v$(VERSION).tar.gz
	rm -f postinstall-pak

check-version:
ifndef VERSION
    $(error VERSION is undefined. Usage make VERSION=x.x.x)
endif
