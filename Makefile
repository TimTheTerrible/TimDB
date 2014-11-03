PERLDIR="/usr/local/share/perl5/"
TARGET="TimDB.pm"

install:
	mkdir -p ${PERLDIR}; \
	cp ${TARGET} ${PERLDIR}
