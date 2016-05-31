PERLDIR=/usr/local/lib64/perl5
TARGET=TimDB.pm

install:
	mkdir -p ${PERLDIR}; \
	cp ${TARGET} ${PERLDIR}

test:
	perl -I . ./test.pl --help

diff:
	diff ${TARGET} ${PERLDIR}/${TARGET}
