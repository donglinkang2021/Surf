.386
.model flat, stdcall
option casemap:none

include windows.inc
include kernel32.inc
includelib kernel32.lib
include user32.inc
includelib user32.lib
include gdi32.inc
includelib gdi32.lib
include resource.inc

.const
	MyWinClass   db "Simple Win Class",0
	AppName      db "Surf",0

.data
	stRect RECT <0,0,0,0>;客户窗口的大小，right代表长，bottom代表高

	itemsCount dd 0	;当前已经加载的图片的数量

.data?
	hInstance dword ? 	;程序的句柄
	hWinMain dword ?	;窗体的句柄

	hBmpBack dd ?		;背景图片的句柄
	hBmpPlayer64 dd ?	;玩家的句柄
	hBmpPlayerM64 dd ?	;玩家mask的句柄
	hBmpSurfB64 dd ?	;冲浪板的句柄
	hBmpSurfBM64 dd ?	;冲浪板mask的句柄

	ITEMBMP struct
		hbp dd ? 	;位图的句柄
		x dd ? 		;位图x坐标
		y dd ?		;位图y坐标
		w dd ?		;位图宽度
		h dd ?		;位图高度
		flag dd ?	;位图的展示方式
	ITEMBMP ends
	items ITEMBMP 4096 dup(<?,?,?,?,?,?>)
	
.code

	;------------------------------------------
	; LoadAllBmp - 加载所有的图片
	; @param
	; @return void
	;------------------------------------------
	LoadAllBmp PROC
		invoke LoadBitmap, hInstance, IDB_BACK
		mov hBmpBack, eax
		invoke LoadBitmap, hInstance, IDB_PLAYER64
		mov hBmpPlayer64, eax
		invoke LoadBitmap, hInstance, IDB_PLAYERM64
		mov hBmpPlayerM64, eax
		invoke LoadBitmap, hInstance, IDB_SURFB64
		mov hBmpSurfB64, eax
		invoke LoadBitmap, hInstance, IDB_SURFBM64
		mov hBmpSurfBM64, eax
		ret
	LoadAllBmp ENDP

	;------------------------------------------
	; DeleteBmp - 删除所有的图片
	; @param
	; @return void
	;------------------------------------------
	DeleteBmp PROC
		invoke DeleteObject, hBmpBack
		invoke DeleteObject, hBmpPlayer64
		invoke DeleteObject, hBmpPlayerM64
		invoke DeleteObject, hBmpSurfB64
		invoke DeleteObject, hBmpSurfBM64
		ret
	DeleteBmp ENDP

	;------------------------------------------
	; Bmp2Buffer - 将图片绘制到缓冲区
	; @param hBmp:HBITMAP
	; @param x:DWORD
	; @param y:DWORD
	; @param w:DWORD
	; @param h:DWORD
	; @param flag:DWORD
	; @return void
	;------------------------------------------
	Bmp2Buffer PROC hBmp:DWORD, x:DWORD, y:DWORD, w:DWORD, h:DWORD, flag:DWORD
		; get the top buffer
		mov eax, itemsCount
		mov edi, offset items
		mov ebx, TYPE ITEMBMP
		mul ebx
		add edi, eax

		; set the buffer
		mov eax, hBmp
		mov (ITEMBMP PTR [edi]).hbp, eax
		mov eax, x
		mov (ITEMBMP PTR [edi]).x, eax
		mov eax, y
		mov (ITEMBMP PTR [edi]).y, eax
		mov eax, w
		mov (ITEMBMP PTR [edi]).w, eax
		mov eax, h
		mov (ITEMBMP PTR [edi]).h, eax
		mov eax, flag
		mov (ITEMBMP PTR [edi]).flag, eax

		; add the count
		inc itemsCount
		ret
	Bmp2Buffer ENDP

	;------------------------------------------
	; Buffer2Window - 将缓冲区的图片绘制到窗口
	; @param hWnd:HWND
	; @return void
	;------------------------------------------
	Buffer2Window PROC
		LOCAL ps:PAINTSTRUCT
		LOCAL hdc:dword ;屏幕的hdc 全称是handle device context
		LOCAL hdc1:dword;缓冲区1
		LOCAL hdc2:dword;缓冲区2
		LOCAL hBmp:dword;缓冲区的位图
		LOCAL @bminfo :BITMAP

		invoke BeginPaint, hWinMain, addr ps
		mov hdc, eax
		invoke CreateCompatibleDC, hdc
		mov hdc1, eax
		invoke CreateCompatibleDC, hdc
		mov hdc2, eax

		; get the window size
		invoke CreateCompatibleBitmap,hdc,stRect.right,stRect.bottom
		mov hBmp,eax
		invoke SelectObject,hdc1,hBmp
		invoke SetStretchBltMode,hdc,HALFTONE
		invoke SetStretchBltMode,hdc1,HALFTONE

		mov esi, 0
		mov edi, offset items
		.while esi < itemsCount
			invoke GetObject,(ITEMBMP PTR [edi]).hbp,type @bminfo,addr @bminfo
			invoke SelectObject,hdc2,(ITEMBMP PTR [edi]).hbp
			invoke StretchBlt,\
				hdc1,\
				(ITEMBMP PTR [edi]).x,(ITEMBMP PTR [edi]).y,\
				(ITEMBMP PTR [edi]).w,(ITEMBMP PTR [edi]).h,\
				hdc2,\
				0,0,\
				@bminfo.bmWidth,@bminfo.bmHeight,\
				(ITEMBMP PTR [edi]).flag
			inc esi
			add edi,TYPE ITEMBMP
		.endw

		invoke StretchBlt,hdc,0,0,\
			stRect.right,stRect.bottom,\
			hdc1,0,0,\
			stRect.right,stRect.bottom,\
			SRCCOPY

		invoke DeleteDC,hBmp
		invoke DeleteDC,hdc2
		invoke DeleteDC,hdc1
		invoke DeleteDC,hdc
		invoke EndPaint, hWinMain, addr ps
		mov itemsCount, 0
		ret
	Buffer2Window ENDP


	;------------------------------------------
	; WndProc - Window procedure
	; @param hWnd:HWND
	; @param uMsg:UINT
	; @param wParam:WPARAM
	; @param lParam:LPARAM
	; @return LRESULT
	; @author linkdom
	;------------------------------------------
	WndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
		.if uMsg==WM_DESTROY
			invoke DeleteBmp
			invoke PostQuitMessage, NULL
		.elseif uMsg==WM_CREATE
			invoke LoadAllBmp
			invoke GetClientRect, hWnd, addr stRect
		.elseif uMsg == WM_PAINT
			invoke Bmp2Buffer, hBmpBack, 0, 0, stRect.right, stRect.bottom, SRCCOPY
			; 64 * 13 
			invoke Bmp2Buffer, hBmpSurfBM64, 0, 0, 832, 192, SRCAND
			invoke Bmp2Buffer, hBmpSurfB64, 0, 0, 832, 192, SRCPAINT
			invoke Bmp2Buffer, hBmpSurfBM64, 0, 192, 832, 192, SRCAND
			invoke Bmp2Buffer, hBmpSurfB64, 0, 192, 832, 192, SRCPAINT
			invoke Bmp2Buffer, hBmpSurfBM64, 0, 384, 832, 192, SRCAND
			invoke Bmp2Buffer, hBmpSurfB64, 0, 384, 832, 192, SRCPAINT
			invoke Bmp2Buffer, hBmpPlayerM64, 0, 0, 832, 576, SRCAND
			invoke Bmp2Buffer, hBmpPlayer64, 0, 0, 832, 576, SRCPAINT
			invoke Buffer2Window
		.else
			invoke DefWindowProc, hWnd, uMsg, wParam, lParam		
			ret
		.endif
		xor eax,eax
		ret
	WndProc ENDP


	;------------------------------------------
	; WinMain - Entry point for our program
	; @param 
	; @author linkdom
	;------------------------------------------
	WinMain PROC
		local	@stWndClass:WNDCLASSEX
		local	@stMsg:MSG
		invoke	GetModuleHandle,NULL
		mov	hInstance,eax	;获取程序的句柄
		invoke	RtlZeroMemory,addr @stWndClass,sizeof @stWndClass
		invoke	LoadCursor,0,IDC_ARROW
		mov	@stWndClass.hCursor,eax
		invoke LoadIcon, hInstance, IDI_ICON1; 
		mov	@stWndClass.hIcon,eax
		mov	@stWndClass.hIconSm,eax
		push hInstance
		pop	@stWndClass.hInstance
		mov	@stWndClass.cbSize,sizeof WNDCLASSEX
		mov	@stWndClass.style,CS_HREDRAW or CS_VREDRAW
		mov	@stWndClass.lpfnWndProc,offset WndProc ;指定窗口处理程序
		mov	@stWndClass.hbrBackground,COLOR_WINDOW + 1
		mov	@stWndClass.lpszClassName,offset MyWinClass;窗口的类名
		invoke	RegisterClassEx,addr @stWndClass
		invoke	CreateWindowEx,WS_EX_CLIENTEDGE,\
				offset MyWinClass,\
				offset AppName,\
				WS_OVERLAPPEDWINDOW,\
				100,100,900,700,\
				NULL,NULL,hInstance,NULL
		mov	hWinMain,eax
		invoke ShowWindow, hWinMain, SW_SHOWDEFAULT 
		invoke UpdateWindow, hWinMain 
		.while	TRUE
			invoke	GetMessage,addr @stMsg,NULL,0,0
			.break	.if eax	== 0
			invoke	TranslateMessage,addr @stMsg
			invoke	DispatchMessage,addr @stMsg
		.endw
		ret
	WinMain ENDP


	main:
		call WinMain
		invoke ExitProcess,NULL
	end main
