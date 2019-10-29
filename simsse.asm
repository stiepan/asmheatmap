;   Heat transmission simulation - 2. assembly assignment
;   Kamil Tokarski, kt361223

            global m_offset_of, m_extra_height, m_offset_top, matrix_no, start, step

            section .bss
matrix_addr             resb 8 ; address of both matrices
heaters_addr            resb 8 ; address of heaters vector
radiators_addr          resb 8 ; address of radiators vector
rad_left_col            resb 8 ; address of the first row in the left radiators column
rad_right_col           resb 8 ; address of the first row in the right radiators column
single_matrix_size      resb 4 ; there are two matrices one by one at the matrix_addr,
                               ; this is the size of single one
step_parity             resb 4 ; depending of step parity one of the matrices 
                               ; is read and one written to
height                  resb 4 ; height of the matrix provided by user 
                               ; (in memory there are [m_extra_height] rows)
width                   resb 4 ; width of the matrix provided by user
offsetted_width         resb 4 ; actual width of the row in the memory - takes into account offset
                               ; that on the one hand assures writes are made to aligned memory
                               ; and on the other makes allowances for place for the radiators values
factor                  resb 4 ; floating point number containing the weight for simulation

            section .text

m_extra_height           dd 2
m_offset_top             dd 1
_four                    dd -4.


m_offset_of:            push rbp
                        mov r9d,edi
                        call m_padding
                        cmp eax,0
                        jle m_offset_of_nonpos ; failed to find padding for the provieded width
                        cmp esi,0 ; second argument is a row index
                        jl m_offset_of_nonpos ; incorrect coulmn index
                        add eax,edi
                        imul eax,esi
                        jmp m_offset_of_finish
m_offset_of_nonpos:     xor eax,eax
m_offset_of_finish:     pop rbp
                        ret


m_padding:              push rbp
                        cmp edi,0 ; first param = width
                        jle m_padding_nonpos
                        call mod4 ; width mod 4 in eax
                        mov r9d,4
                        sub r9d,eax ; 4 - width mod 4
                        mov eax,r9d
                        cmp eax, 1
                        je m_not_enough_room ; radiators won't fit in
                        jmp m_padding_finish
m_not_enough_room:      mov eax,5
                        jmp m_padding_finish
m_padding_nonpos:       xor eax,eax
m_padding_finish:       pop rbp
                        ret


mod4:                   push rbp
                        mov r8d,edi
                        shr r8d,2 
                        shl r8d,2 
                        mov eax,edi
                        sub eax,r8d
                        pop rbp
                        ret


start:                  push rbp
                        mov [rel width],edi
                        mov [rel height],esi
                        mov [rel matrix_addr],rdx
                        mov [rel heaters_addr],rcx
                        mov [rel radiators_addr],r8
                        movss [rel factor], xmm0
                        add esi,2
                        call m_offset_of
                        mov [rel single_matrix_size],eax
                        mov esi,1
                        call m_offset_of
                        mov [rel offsetted_width],eax
                        mov rdx, [rel matrix_addr]
                        lea r9,[rdx + 4 * rax - 4]
                        mov [rel rad_left_col],r9
                        mov edx,[rel width]
                        lea r9,[r9 + 4 * rdx + 4]
                        mov [rel rad_right_col],r9
                        mov dword [rel step_parity],0
                        call reset_heaters
start_finish:           pop rbp
                        ret


reset_heaters:          push rbp
                        mov ecx,[rel single_matrix_size]
                        mov r9d,[rel width]
                        test r9,r9
                        je reset_heaters_end
                        mov rdi,[rel matrix_addr] ; up heaters of the fst matrix
                        lea rsi,[rdi + 4 * rcx] ; up heaters of the snd matrix

enter_loop:             mov r8,[rel heaters_addr] ; heaters values vector
                        lea r11,[r8 + 4 * r9] ; address after the last heater
heaters_loop:           movss xmm0,[r8]
                        movss [rdi],xmm0
                        movss [rsi],xmm0
                        add rdi,4
                        add rsi,4
                        add r8,4
                        cmp r8,r11
                        jl heaters_loop

                        test ecx,ecx ; now update down rows or jump end if it's been done
                        je reset_heaters_end
                        mov r10d,[rel offsetted_width]
                        shl r10,2
                        mov rdi,[rel matrix_addr]
                        lea rdi,[rdi + 4 * rcx]; down heaters of the fst matrix
                        sub rdi,r10
                        lea rsi,[rdi + 4 * rcx] ; down heaters of the snd matrix
                        mov ecx,0
                        jmp enter_loop

reset_heaters_end:      pop rbp
                        ret


step:                   push rbp
                        mov edi,[rel step_parity]
                        xor edi,1
                        mov [rel step_parity],edi ; if step_no (from edi) is even now second matrix
                                                  ; will be read from and the first one otherwise
                        push rdi
                        call reset_radiators
                        pop rdi ; step parity
                        call _set_matrx_ptrs ; matrices in rsi(read) and
                                             ; rdx(write only up to rcx)
                        lea r8,[rsi - 4] ; (float *)matrix - 1
                        lea r9,[rsi + 4] ; (float *)matrix + 1
                        mov edi,[rel offsetted_width]
                        lea r10,[rsi + 4 * rdi] ; next row same column
                        shl rdi,2
                        mov r11,rsi
                        sub r11,rdi ; previous row same column
                        cmp rdx,rcx
                        jge step_finish
                        movss xmm6,[rel factor]
                        movss xmm5,[rel _four]
                        shufps xmm6,xmm6,0x0
                        shufps xmm5,xmm5,0x0
step_loop:              movaps xmm0,[r11]
                        movaps xmm1,[r10]
                        addps xmm0,xmm1
                        movups xmm1,[r9]
                        addps xmm0,xmm1
                        movups xmm1,[r8]
                        addps xmm0,xmm1 ; now xmm0 cantains a sum of neighbours for 4 consecutive cells
                        movaps xmm2,[rsi]
                        movaps xmm1,xmm2
                        mulps xmm1,xmm5
                        addps xmm0,xmm1
                        mulps xmm0,xmm6 ; sum of differences with neighbours times weight
                        addps xmm0,xmm2
                        movaps [rdx],xmm0
                        add rsi,16
                        add rdx,16
                        add r11,16
                        add r10,16
                        add r9,16
                        add r8,16
                        cmp rdx,rcx
                        jl step_loop
step_finish:            pop rbp
                        ret


_set_matrx_ptrs:        push rbp ; expects step parity in edi and sets rsi and rdx to
                                 ; matrices that ouhght to be respectively read from and written to,
                                 ; rcx contains address after the last that should be written to
                        mov rsi,[rel matrix_addr]
                        mov r10d,[rel offsetted_width]
                        mov r11d,[rel single_matrix_size]
                        lea rsi, [rsi + 4 * r10] ; skip first row
                        mov rdx,rsi
                        lea r9,[rsi + 4 * r11] ; beg of second row in second matrix
                        test edi,edi
                        je read_from_second
                        mov rdx,r9
                        jmp _set_matrx_ptrs_end
read_from_second:       mov rsi,r9
_set_matrx_ptrs_end:    lea rcx, [rdx + 4 * r11]
                        shl r10,3 ; 2 rows each cell 4 bytes
                        sub rcx,r10 ; beg of last row in matrix to write to
                        pop rbp
                        ret


reset_radiators:        push rbp
                        mov rdi,[rel rad_left_col] ; float * left radiators column
                        mov r8,[rel rad_right_col] ; float * right radiators column
                        mov r10d,[rel step_parity] ; adjust column addresess if the
                        test r10d,r10d             ; second matrix is going to be read from
                        jne radiators_continue
                        mov r10d,[rel single_matrix_size]
                        lea rdi,[rdi + 4 * r10]
                        lea r8,[r8 + 4 * r10]
radiators_continue:     mov rsi,[rel radiators_addr] ; float * radiators values
                        mov r9d, [rel offsetted_width] ; actual columns count
                        shl r9,2 ; width of a single row in bytes
                        mov ecx,[rel height] ; number of rows
                        test rcx,rcx
                        je reset_radiators_finish
                        lea rcx,[rsi + 4 * rcx] ; final address in radiators values vector

radiators_loop:         movss xmm0,[rsi]
                        movss [rdi],xmm0
                        movss [r8],xmm0
                        add rdi,r9
                        add r8,r9
                        add rsi,4
                        cmp rsi,rcx
                        jl radiators_loop

reset_radiators_finish: pop rbp
                        ret

