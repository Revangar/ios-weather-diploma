#include <stdio.h>
#include <stdlib.h>
typedef struct {char *builtin; unsigned char *data; size_t size;} *sandbox_profile_t;
extern sandbox_profile_t sandbox_compile_string(const char *, void *, char **);
int main(int argc,char **argv) {
    char *error=0;
    sandbox_profile_t profile=sandbox_compile_string("(version 1)(allow default)(deny network-outbound)(allow network-outbound (remote ip \"localhost:*\"))",0,&error);
    if (!profile) { fprintf(stderr,"profile compile failed: %s\n",error);return 1; }
    FILE *output=fopen(argv[1],"wb");if(!output)return 2;
    fwrite(profile->data,1,profile->size,output);fclose(output);
    fprintf(stderr,"compiled %zu bytes\n",profile->size);return 0;
}
