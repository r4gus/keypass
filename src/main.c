#include <stdio.h>
#include <signal.h>
#include <string.h> // memcpy(),
#include "keylib/keylib.h"
#include "keylib/uhid.h" // uhid_open(), uhid_close()
#include "csv/csv.h"

#define CSV_PATH "test.csv"

int up(const char* info, const char* user, const char* rp) {
    printf("up\n");
    return 1;
}

int uv(const char* info, const char* user, const char* rp) {
    printf("uv\n");
    return 1;
}

int select_cred(const char* rpId, char** users, size_t len) {
    printf("select\n");
    return -1;
}

int auth_read(const char* id, const char* rp, Data** out) {
    Csv csv = csv_open(CSV_PATH);
    if (csv == NULL) {
        printf("error: unable to open file %s\n", CSV_PATH);
        return DoesNotExist;
    }

    if (id) {
        Row row;
        while (row = csv_next(csv)) {
            size_t l;
            char* id2 = csv_row_next(row, &l);
            if (id2 == NULL) {
                continue;
            }
            if (l == strlen(id) && strncmp(id, id2, l) == 0) { // found
                csv_row_next(row, &l);        
                char* data = csv_row_next(row, &l);        
                if (data == NULL) {
                    return Other;
                }
                
                Data* x = malloc(sizeof(Data) * 2);
                x[0].payload = malloc(l);
                memcpy(x[0].payload, data, l);
                x[0].len = l;

                x[1].payload = 0;
                x[1].len = 0;
                *out = x;

                return SUCCESS;
            }
        }
        return DoesNotExist;
    } else if (rp) {
        size_t count = 0;
        Data* x = NULL;
        Row row;
        while (row = csv_next(csv)) {
            size_t l;
            csv_row_next(row, &l);
            char* rp2 = csv_row_next(row, &l);
            if (rp2 == NULL) {
                continue;
            }
            if (l == strlen(id) && strncmp(rp, rp2, l) == 0) { // found
                char* data = csv_row_next(row, &l);        
                if (data == NULL) {
                    continue; // TODO: just continue if data is malformed
                }

                count++;

                if (count == 1) {
                    x = malloc(sizeof(Data) * 2);
                } else {
                    x = realloc(x, sizeof(Data) * (count + 1));
                }
                
                x[count - 1].payload = malloc(l);
                memcpy(x[count - 1].payload, data, l);
                x[count - 1].len = l;
            }
        }

        if (count == 0) {
            return DoesNotExist;
        } else {
            x[count].payload = 0;
            x[count].len = 0;
            *out = x;
            return SUCCESS;
        }
    } else {
        // TODO: get all
    }

    csv_close(csv);

    return DoesNotExist;
}

int auth_write(const char* id, const char* rp, const char* data, size_t data_len) {
    int ret = SUCCESS;
    Csv csv = csv_open(CSV_PATH);
    if (csv == NULL) {
        printf("error: unable to open file %s\n", CSV_PATH);
        return DoesNotExist;
    }
    
    size_t sl = strlen(id) + strlen(rp) + data_len + 2;
    char* s = malloc(sl);
    sprintf(s, "%s,%s,%.*s", id, rp, data_len, data);
    
    int found = 0; 
    size_t index = 0;
    Row row;
    while (row = csv_next(csv)) {
        size_t l;
        char* id2 = csv_row_next(row, &l);
        if (id2 == NULL) {
            continue;
        }
        if (l == strlen(id) && strncmp(id, id2, l) == 0) { // found
            found = 1;
            if (csv_set(csv, index, s, sl) < 0) {
                printf("error: unable to update csv file\n");
                ret = Other;
            }
            break;
        }
        index++;
    }

    if (!found) {
        if (csv_append(csv, s, sl) < 0) {
            printf("error: unable to update csv file\n");
            ret = Other;
        }
    }
    
    free(s);
    csv_write(csv, NULL); // we write to the same file we read from
    csv_close(csv);
    return ret;
}

int auth_delete(const char* id, const char* rp) {
    printf("delete\n");
    return -1;
}

static int CLOSE = 0;

void sigint_handler(sig_t s) {
    CLOSE = 1;
}

int main() {
    Callbacks c = {
        up, uv, select_cred, auth_read, auth_write, auth_delete
    }; 

    // -------------------------------------------------------
    // Init Start
    // -------------------------------------------------------
    
    // Instantiate the authenticator
    void* auth = auth_init(c);

    // Instantiate a ctaphid handler
    void* ctaphid = ctaphid_init();

    // Now lets create a (virtual) USB-HID device
    int fd = uhid_open();

    // -------------------------------------------------------
    // Init End
    // -------------------------------------------------------
    
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Main Start
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    while (!CLOSE) {
        char buffer[64];
        
        int packet_length = uhid_read_packet(fd, &buffer[0]);
        if (packet_length) {
            // The handler will either return NULL or a pointer to
            // a ctaphid packet iterator.
            void* iter = ctaphid_handle(ctaphid, &buffer[0], packet_length, auth);

            // Every call to next will return a 64 byte packet ready
            // to be sent to the host. 
            if (iter) {
                char out[64];

                while(ctaphid_iterator_next(iter, &out[0])) {
                    uhid_write_packet(fd, &out[0], 64);
                }

                // Don't forget to free the iterator
                ctaphid_iterator_deinit(iter);
            }
        }
    }
    
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Main End
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++

    // -------------------------------------------------------
    // Deinit Start
    // -------------------------------------------------------

    // We have to clean up the (virtual) USB-HID device we created
    uhid_close(fd);
    
    // Free the ctaphid instance
    ctaphid_deinit(ctaphid);

    // Free the authenticator instance
    auth_deinit(auth);

    // -------------------------------------------------------
    // Deinit End
    // -------------------------------------------------------

    return 0;
}
