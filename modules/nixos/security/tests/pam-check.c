/* Exercise a private PAM directory. Never touch /etc/pam.d or real credentials. */
#include <security/pam_appl.h>
#include <stdio.h>

static int reject_prompt(int count, const struct pam_message **messages,
                         struct pam_response **responses, void *data) {
    (void)count;
    (void)messages;
    (void)responses;
    (void)data;
    return PAM_CONV_ERR;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: pam-check CONFIG_DIR SERVICE\n");
        return 2;
    }
    const struct pam_conv conversation = {reject_prompt, NULL};
    pam_handle_t *handle = NULL;
    int status = pam_start_confdir(argv[2], "test-user", &conversation, argv[1], &handle);
    if (status != PAM_SUCCESS) {
        fprintf(stderr, "pam_start_confdir failed: %d\n", status);
        return 2;
    }
    status = pam_authenticate(handle, PAM_DISALLOW_NULL_AUTHTOK);
    printf("%s: %s\n", argv[2], pam_strerror(handle, status));
    pam_end(handle, status);
    return status == PAM_SUCCESS ? 0 : 1;
}
