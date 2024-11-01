{ pkgs, pname }:
# Used to resolve cache.nixos.org with a fake address inside of tests
pkgs.stdenv.mkDerivation {
  name = pname;
  src = pkgs.runCommand "source" { } ''
    mkdir -p $out
    cat > $out/fakecache.c << EOF
    #define _GNU_SOURCE
    #include <dlfcn.h>
    #include <netdb.h>
    #include <string.h>
    #include <stdio.h>

    int getaddrinfo(const char *node, const char *service,
                    const struct addrinfo *hints, struct addrinfo **res) {
        if (strcmp(node, "cache.nixos.org") == 0) {
            static struct addrinfo fake_info;
            static struct sockaddr_in fake_addr;

            // Fill in fake address details
            fake_addr.sin_family = AF_INET;
            fake_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1
            fake_addr.sin_port = htons(1234); // Port 1234

            fake_info.ai_family = AF_INET;
            fake_info.ai_socktype = SOCK_STREAM;
            fake_info.ai_addr = (struct sockaddr *)&fake_addr;
            fake_info.ai_addrlen = sizeof(fake_addr);

            *res = &fake_info;
            return 0; // Success
        }

        // Call the original getaddrinfo
        static int (*original_getaddrinfo)(const char *, const char *,
                                           const struct addrinfo *,
                                           struct addrinfo **) = NULL;
        if (!original_getaddrinfo) {
            original_getaddrinfo = dlsym(RTLD_NEXT, "getaddrinfo");
        }
        return original_getaddrinfo(node, service, hints, res);
    }
    EOF
  '';

  nativeBuildInputs = [ pkgs.gcc ];

  buildPhase = ''
    gcc -fPIC -shared -o libfakecache.so fakecache.c -ldl
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp libfakecache.so $out/lib/
  '';

  # To demonstrate the use of the LD_PRELOAD library
  testPhase = ''
    export LD_PRELOAD=$out/lib/libfakecache.so
    echo "Testing with LD_PRELOAD set"
    # Example command to test; this can be any command that tries to resolve "fakecache.com"
    getent hosts cache.nixos.org || echo "Fake host resolution failed"
  '';
}
