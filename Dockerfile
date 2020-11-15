FROM centos:7.9.2009 as active-perl

ENV ACTIVE_PERL_VERSION=5.28

RUN set -x \
    && yum install which -y \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && sh -c "$(curl -q https://platform.activestate.com/dl/cli/install.sh | sed 's/^RESPONSE=.\+/RESPONSE=y/g' | sed 's/ \([][]\)\([ ;]\)/ \1\1\2/g' | sed 's/-or/||/g' | sed 's/^\(\s*if [^]]\+\) -a /\1 \&\& /g')" -- -n || exit 1

RUN set -x \
    && state activate --default ActiveState/ActivePerl-$ACTIVE_PERL_VERSION --path /usr/local/lib/perl

FROM active-perl as builder

ENV TAO_VERSION=6.5.12

ENV ACE_ROOT=/opt/ACE
ENV LD_LIBRARY_PATH=$ACE_ROOT/ace/lib:$LD_LIBRARY_PATH
ENV TAO_ROOT=$ACE_ROOT/TAO
ENV TAO_HOME=/usr/local/tao

ARG BUILD_STATIC_LIBS_ONLY=0
ENV BUILD_STATIC_LIBS_ONLY=$BUILD_STATIC_LIBS_ONLY

RUN set -eux \
    && yum groupinstall "Development Tools" -y \
    && yum update -y \
    && yum clean all \
    && rm -rf /var/cache/yum
    
RUN set -eux; \
    BINARY_URL="http://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-${TAO_VERSION//./_}/ACE%2BTAO-${TAO_VERSION}.tar.gz" \
    && mkdir -p $ACE_ROOT \
    && curl -LfSo /tmp/tao.tar.gz ${BINARY_URL} \
    && tar -zxf /tmp/tao.tar.gz  --strip-components=1 -C $ACE_ROOT \
    && cd $ACE_ROOT \
    && echo '#include "ace/config-linux.h"' \
      > ace/config.h \
    && echo 'include $(ACE_ROOT)/include/makeinclude/platform_linux.GNU' \
      > include/makeinclude/platform_macros.GNU \
    && echo 'TAO_ORBSVCS = Naming Time Trader ImplRepo' \
      >> include/makeinclude/platform_macros.GNU \
    && echo "static_libs_only = ${BUILD_STATIC_LIBS_ONLY}" \
      >> include/makeinclude/platform_macros.GNU \
    && export INSTALL_PREFIX=$TAO_HOME \
    && make -C $ACE_ROOT/ace \
    && make -C $ACE_ROOT/apps/gperf/src \
    && make -C $TAO_ROOT install

FROM centos:7.9.2009

LABEL maintainer="Pengxuan Men <pengxuan.men@gmail.com>"

ENV TAO_VERSION=6.5.12
ENV TAO_HOME=/usr/local/tao
ENV PATH="$TAO_HOME/bin:$PATH"

COPY --from=builder /usr/local/tao $TAO_HOME

EXPOSE 683

VOLUME [ "/var/lib/tao/naming.ior" ]

CMD [ "tao_cosnaming", "-d", "-o", "/var/lib/tao/naming.ior", "-ORBListenEndpoints", "iiop://:683" ]
