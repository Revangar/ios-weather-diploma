#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
// Diagnostic process-only OS network restriction, outside the application source/bundle.
__attribute__((constructor)) static void restrict_network(void) {
    typedef int (*apply_fn)(const void *, size_t, const char *);
    apply_fn apply = (apply_fn)dlsym(RTLD_DEFAULT, "sandbox_apply_bytecode");
    FILE *file=fopen("/Users/incar/Documents/Codex/2026-10-30/codex-weather-diploma-task-md-mac/work/review-20261101/deny-network.sb.bin","rb");
    if (!file || !apply) { fprintf(stderr,"WEATHER_REVIEW_NETWORK_SANDBOX unsupported\n");return; }
    fseek(file,0,SEEK_END);long size=ftell(file);rewind(file);
    void *data=malloc(size);fread(data,1,size,file);fclose(file);
    int status=apply(data,size,NULL);
    fprintf(stderr,"WEATHER_REVIEW_NETWORK_SANDBOX result=%d errno=%d\n",status,errno);
    free(data);
}
