NAME=muppet
VERSION=1.1.0
$(shell ./set-version-number.tcl ${NAME} ${VERSION})
RELEASE=$(shell cat RELEASE)
MAINTAINER=hackers@qcode.co.uk
REMOTEUSER=debian.qcode.co.uk
REMOTEHOST=debian.qcode.co.uk
REMOTEDIR=debian.qcode.co.uk

.PHONY: all test

all: test package upload clean incr-release
package: 
	 checkinstall -D --deldoc --backup=no --install=no --pkgname=$(NAME) --pkgversion=$(VERSION) --pkgrelease=$(RELEASE) -A all -y --maintainer $(MAINTAINER) --pkglicense="BSD" --reset-uids=yes --requires "tcl8.5,tcllib,qcode-2.0,iproute,tdom" make install

test: 
	./pkg_mkIndex tcl
	tclsh ./test_all.tcl -testdir test

install: 
	./pkg_mkIndex tcl
	mkdir -p /usr/lib/tcltk/$(NAME)$(VERSION)
	rm -f /usr/lib/tcltk/$(NAME)$(VERSION)/*
	cp tcl/*.tcl /usr/lib/tcltk/$(NAME)$(VERSION)/
	cp LICENSE /usr/lib/tcltk/$(NAME)$(VERSION)/
	cp bin/muppet /usr/local/bin/muppet
	cp muppet.tcl.conf /etc/muppet.tcl.sample

upload:
	scp $(NAME)_$(VERSION)-$(RELEASE)_all.deb "$(REMOTEUSER)@$(REMOTEHOST):$(REMOTEDIR)/debs"	
	ssh $(REMOTEUSER)@$(REMOTEHOST) reprepro -b $(REMOTEDIR) includedeb squeeze $(REMOTEDIR)/debs/$(NAME)_$(VERSION)-$(RELEASE)_all.deb
	ssh $(REMOTEUSER)@$(REMOTEHOST) reprepro -b $(REMOTEDIR) includedeb wheezy $(REMOTEDIR)/debs/$(NAME)_$(VERSION)-$(RELEASE)_all.deb

clean:
	rm $(NAME)_$(VERSION)-$(RELEASE)_all.deb

incr-release:
	./incr-release-number.tcl

uninstall:
	rm -r /usr/lib/tcltk/$(NAME)$(VERSION)
	rm /usr/local/bin/muppet
