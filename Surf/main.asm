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
	freshTime dword 16		;刷新时间，以毫秒为单位 帧率60

	itemsCount dd 0	;当前已经加载的图片的数量

	Player struct
		x dd ?			; 初始在屏幕中的x位置
		y dd ?			; 初始在屏幕中的y位置
		w dd ? 			; 在屏幕中绘制的w
		h dd ? 			; 在屏幕中绘制的h
		role dd ?		; 0~8  9个role可以选择
		action dd ?		; 0~12 13个action可以选择
		surfBframe dd ?		; 0~2  3个frame可以选择
	Player ends

	; surfer.action
	; 0 ~ 5 原地, 左左, 左, 中, 右, 右右
	; 6 ~ 7 落水0, 落水1
	; 8 站着 
	; 9 ~ 12 翻滚0, 翻滚1, 翻滚2, 翻滚3
	surfer Player <368, 236, 64, 64, 0, 3, 0>

	; player_state
	; 自己定义
	; 0 普通划水
	; 1 加速 无动作，只是变快
	; 2 起飞 翻滚开始动作
	; 3 落水
	; 4 站着
	player_state dword 2

.data?
	hInstance dword ? 	;程序的句柄
	hWinMain dword ?	;窗体的句柄

	hBmpBack dd ?		;背景图片的句柄
	hBmpPlayer64 dd ?	;玩家的句柄
	hBmpPlayerM64 dd ?	;玩家mask的句柄
	hBmpSurfB64 dd ?	;冲浪板的句柄
	hBmpSurfBM64 dd ?	;冲浪板mask的句柄

	; 从一个bmp中选择一部分绘制到窗口中
	; xywh 是基于屏幕的相对坐标，是指画在屏幕的哪个位置以及画多大
	; selectxywh 是基于bmp图片的相对坐标，是指从图片的哪个位置开始选择，选择多大
	ITEMBMP struct
		hbp dd ? 	;位图的句柄
		x dd ? 		;位图x坐标
		y dd ?		;位图y坐标
		w dd ?		;位图宽度
		h dd ?		;位图高度
		selectX dd ?	;位图的选择x坐标
		selectY dd ?	;位图的选择y坐标
		selectW dd ?	;位图的选择宽度
		selectH dd ?	;位图的选择高度
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
	; @param sx:DWORD
	; @param sy:DWORD
	; @param sw:DWORD
	; @param sh:DWORD
	; @param flag:DWORD
	; @return void
	;------------------------------------------
	Bmp2Buffer PROC uses eax ebx ecx edx esi edi hBmp:DWORD, x:DWORD, y:DWORD, w:DWORD, h:DWORD, sx:DWORD, sy:DWORD, sw:DWORD, sh:DWORD, flag:DWORD
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
		mov eax, sx
		mov (ITEMBMP PTR [edi]).selectX, eax
		mov eax, sy
		mov (ITEMBMP PTR [edi]).selectY, eax
		mov eax, sw
		mov (ITEMBMP PTR [edi]).selectW, eax
		mov eax, sh
		mov (ITEMBMP PTR [edi]).selectH, eax
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
			invoke GetObject,(ITEMBMP PTR [edi]).hbp, type @bminfo,addr @bminfo
			invoke SelectObject,hdc2,(ITEMBMP PTR [edi]).hbp
			invoke StretchBlt,\
				hdc1,\
				(ITEMBMP PTR [edi]).x,(ITEMBMP PTR [edi]).y,\
				(ITEMBMP PTR [edi]).w,(ITEMBMP PTR [edi]).h,\
				hdc2,\
				(ITEMBMP PTR [edi]).selectX,(ITEMBMP PTR [edi]).selectY,\
				(ITEMBMP PTR [edi]).selectW,(ITEMBMP PTR [edi]).selectH,\
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
	; RenderSurfer - 绘制 player 和 surfboard
	; @param
	; @return void
	;------------------------------------------
	RenderSurfer PROC uses eax ebx ecx edx esi edi 
		mov edi, surfer.action
		shl edi, 6
		mov esi, surfer.surfBframe
		shl esi, 6
		invoke Bmp2Buffer, hBmpSurfBM64, surfer.x, surfer.y, surfer.w, surfer.h, edi, esi, 64, 64, SRCAND
		invoke Bmp2Buffer, hBmpSurfB64, surfer.x, surfer.y, surfer.w, surfer.h, edi, esi, 64, 64, SRCPAINT
		mov esi, surfer.role
		shl esi, 6
		invoke Bmp2Buffer, hBmpPlayerM64, surfer.x, surfer.y, surfer.w, surfer.h, edi, esi, 64, 64, SRCAND
		invoke Bmp2Buffer, hBmpPlayer64, surfer.x, surfer.y, surfer.w, surfer.h, edi, esi, 64, 64, SRCPAINT
		xor eax, eax
		ret
	RenderSurfer ENDP

	;------------------------------------------
	; PlayerRole - 玩家的切换角色
	; @param wParam:WPARAM
	; @return void
	;------------------------------------------
	PlayerRole PROC uses eax ebx ecx edx esi edi wParam:WPARAM
		.if wParam==VK_Q
			.if surfer.role > 0
				dec surfer.role
			.else
				mov eax, 8
				mov surfer.role, eax
			.endif
		.elseif wParam==VK_E
			.if surfer.role < 8
				inc surfer.role
			.else
				mov eax, 0
				mov surfer.role, eax
			.endif
		.endif
		xor eax, eax
		ret
	PlayerRole ENDP

	;------------------------------------------
	; PlayerAction - 玩家的切换操作
	; @param wParam:WPARAM
	; @return void
	;------------------------------------------
	PlayerAction PROC uses eax ebx ecx edx esi edi wParam:WPARAM 
		.if wParam==VK_LEFT || wParam==VK_A 
			.if surfer.action > 1 && surfer.action < 6
				.if surfer.action > 3
					mov eax, 2
					mov surfer.action, eax
				.else
					dec surfer.action
				.endif
			.endif
		.elseif wParam==VK_RIGHT || wParam==VK_D
			.if surfer.action < 5 && surfer.action > 0
				.if surfer.action < 3
					mov eax, 4
					mov surfer.action, eax
				.else
					inc surfer.action
				.endif
			.endif
		.elseif wParam==VK_DOWN || wParam==VK_S
			.if player_state == 0
				mov eax, 3
				mov surfer.action, eax
			.elseif player_state == 2
				.if surfer.action < 6
					mov eax, 9
					mov surfer.action, eax
				.elseif surfer.action >= 9 && surfer.action < 12
					inc surfer.action
				.elseif surfer.action == 12
					mov eax, 3
					mov surfer.action, eax
				.endif
			.endif
		.elseif wParam==VK_UP || wParam==VK_W
			mov eax, 0
			mov surfer.action, eax
		.endif
		xor eax, eax
		ret
	PlayerAction ENDP

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
			invoke SetTimer,hWnd,1,freshTime,NULL ; 开始计时
		.elseif uMsg==WM_KEYDOWN
			invoke PlayerAction, wParam
			invoke PlayerRole, wParam
		.elseif uMsg == WM_PAINT
			invoke Bmp2Buffer, hBmpBack, 0, 0, stRect.right, stRect.bottom, 0, 0, stRect.right, stRect.bottom, SRCCOPY
			invoke RenderSurfer
			invoke Buffer2Window
		.elseif uMsg ==WM_TIMER ;刷新
			invoke InvalidateRect,hWnd,NULL,FALSE
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
				100,100,800,700,\
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
