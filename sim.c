/*
    Heat transmission simulation - 2. assembly assignment
    Kamil Tokarski, kt361223
    Usage: sim input_filename heat_transfer_factor no_steps
    It is not enforced in the code but presumably only
    sensible heat transfer factors fall within the range [0, 0.25].
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct Simulation
{
    float* matrix; // two matrices one by one each containing simulation
                   // description padded so that all cells apart from 
                   // radiators values have aligned addresses
    float* heater; // vector of heaters
    float* radiator;
    float factor;
    int width, height, steps;
};


typedef struct Simulation * Simulation;


char last_error[1000];


extern int m_offset_of(int width, int row); // address of first cell in the [row] row
                                            // in padded matrix
extern int const m_offset_top, m_extra_height;

extern void start(int width, int height, float *M, float *G, float *C, float factor);
extern void step();


void free_simulation(Simulation s)
{
    if(!s) {
        return;
    }
    if(s->radiator) {
        free(s->radiator);
    }
    if(s->heater) {
        free(s->heater);
    }
    if(s->matrix) {
        free(s->matrix);
    }
    free(s);
}

int load_line(FILE* fptr, float* dest, int size)
{
    for(int i = 0; i < size; i++) {
        if (fscanf(fptr, "%f", dest + i) != 1) {
            return 1;
        }
    }
    return 0;
}

int load_matrix(FILE* fptr, Simulation s)
{
    for(int r = m_offset_top; r < m_offset_top + s->height; r++) {
        int offset = m_offset_of(s->width, r);
        if (load_line(fptr, s->matrix + offset, s->width)) {
            return 1;
        }
    }
    return 0;
}

Simulation load_simulation(FILE* fptr)
{
    Simulation s = (Simulation)malloc(sizeof(*s));
    int done = 0;

    do {
        if (!s) {
            sprintf(last_error, "Malloc failure (1)");
            break;
        }
        s->factor = 0.25;
        s->steps = 1;
        s->radiator = s->heater = s->matrix = NULL;
        fscanf(fptr, "%d%d", &s->width, &s->height);
        int msize = m_offset_of(s->width, s->height + m_extra_height);
        if (msize <= 0) {
            sprintf(last_error, "Incorrect size (w: %d h: %d)", s->width, s->height);
            break;
        }
        if(posix_memalign((void *)&s->matrix, 16, 2 * msize * sizeof(*s->matrix))) {
            sprintf(last_error, "Memalign error (1)");
            break;
        }
        if(!(s->heater = (float *)malloc(s->width * sizeof(*s->heater)))) {
            sprintf(last_error, "Malloc failure (2)");
            break;
        }
        if(!(s->radiator = (float *)malloc(s->height * sizeof(*s->radiator)))) {
            sprintf(last_error, "Malloc failure (3)");
            break;
        }
        if(load_matrix(fptr, s)) {
            sprintf(last_error, "Error while reading matrix in");
            break;
        }
        if(load_line(fptr, s->heater, s->width)) {
            sprintf(last_error, "Error while reading heaters");
            break;
        }
        if(load_line(fptr, s->radiator, s->height)) {
            sprintf(last_error, "Error while reading heaters");
            break;
        }
        done = 1;
    }
    while(0);

    if (done) {
        return s;
    }

    free_simulation(s);
    return NULL;
}

void print_simulation(int step, Simulation s)
{
    int global_offset = !(step % 2)? 0 : m_offset_of(s->width, s->height + m_extra_height);
    for(int r = m_offset_top; r < m_offset_top + s->height; r++) {
        int offset = m_offset_of(s->width, r) + global_offset;
        for(int c = 0; c < s->width; c++) {
            printf("%f ", s->matrix[offset + c]);
        }
        printf("\n");
    }
}

int main(int argv, char** argc)
{
    FILE* fptr = NULL;
    Simulation s = NULL;
	
    do {
        if (argv < 2 || argv > 4) {
            sprintf(last_error,
                "Usage: %s filename [heat_transfer_factor [no_steps]]\n"
                "Factor is a float number but sensible values fall within [0; 0.25] range.\n"
                "By default factor equals 0.25 and no_steps is 1.", argc[0]);
            break;
        }
        fptr = fopen(argc[1], "r");
        if (!fptr) {
            sprintf(last_error, "Could not open file '%s'", argc[1]);
            break;
        }
        if (!(s = load_simulation(fptr))) {
            break;
        }
        if (argv >= 3) {
            s->factor = atof(argc[2]);
        }
        if (argv >= 4) {
            s->steps = atoi(argc[3]);
        }
        
        start(s->width, s->height, s->matrix, s->heater, s->radiator, s->factor);
        for (int i = 1; i <= s->steps; i++) {
            step();
            print_simulation(i, s);
            if (i != s->steps) {
                printf("\n");
            }
            while (getchar() != '\n');
        }
    }
    while (0);

    free_simulation(s);

    if (fptr) {
        if (fclose(fptr)) {
            sprintf(last_error, "Error while closing the file");
        }
    }

    if (strlen(last_error)) {
        printf("%s\n", last_error);
    }

    return 0;
}
