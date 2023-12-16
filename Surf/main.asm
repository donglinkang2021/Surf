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
include	masm32.inc
includelib msvcrt.lib
rand	proto C

.const
	MyWinClass   db "Simple Win Class",0
	AppName      db "Surf",0

.data
	stRect RECT <0,0,0,0>;客户窗口的大小，right代表长，bottom代表高
	freshTime dword 16		;刷新时间，以毫秒为单位 帧率60
	aniTimer dword 0		;动画计时器，用于控制动画的刷新速度

	itemsCount dd 0	;当前已经加载的图片的数量

	PosWater struct
		x dd ?
		y dd ?
	PosWater ends
	water PosWater <16,-84>

	; 添加相对速度，因为到时候所有物体速度都是一样的
	RelSpeed struct
		x dd ?
		y dd ?
	RelSpeed ends
	speed RelSpeed <0,0>

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
	surfer Player <624, 236, 64, 64, 0, 0, 0>
	; 1312x784 就是全屏这里
	; 1312 / 2 - 64 / 2 = 624

	; player_state
	; 自己定义
	; 0 普通划水
	; 1 加速 无动作，只是变快
	; 2 起飞 翻滚开始动作
	; 3 落水
	; 4 站着
	player_state dword 2

	; 记录生成的slowdown的数量
	slowdCount dd 0
	slowdInterval dd 20 ; 最开始时的生成间隔，80差不多应该，之后的生成间隔为随机数
	MAXSLOWD dd 8 ; 最多生成的slowdown的数量

	; 记录生成的ambient的数量
	ambiCount dd 0
	ambiInterval dd 20 ; 最开始时的生成间隔，40差不多应该，之后的生成间隔为随机数
	MAXAMBI dd 1 ; 最多生成的ambient的数量

	; 记录生成的interact的数量
	interCount dd 0
	interInterval dd 20 ; 最开始时的生成间隔，40差不多应该，之后的生成间隔为随机数
	MAXINTER dd 1 ; 最多生成的interact的数量

.data?
	hInstance dword ? 	;程序的句柄
	hWinMain dword ?	;窗体的句柄

	hBmpBack dd ?		;背景图片的句柄
	hBmpWater dd ?		;浪花的句柄, 浪花暂时不需要mask
	hBmpPlayer64 dd ?	;玩家的句柄
	hBmpPlayerM64 dd ?	;玩家mask的句柄
	hBmpSurfB64 dd ?	;冲浪板的句柄
	hBmpSurfBM64 dd ?	;冲浪板mask的句柄
	hBmpSlowd64 dd ?	;减速物体的句柄
	hBmpSlowdM64 dd ?	;减速物体mask的句柄
	hBmpAmbient64 dd ?	;氛围物体的句柄
	hBmpAmbientM64 dd ?	;氛围物体mask的句柄

	; 后面弄group可能用上，下面的没实现
	hBmpObjects32 dd ?	;物体的句柄
	hBmpObjectsM32 dd ?	;物体mask的句柄
	hBmpObjects64 dd ?	;物体的句柄
	hBmpObjectsM64 dd ?	;物体mask的句柄
	hBmpInteract64 dd ?	;交互物体的句柄
	hBmpInteractM64 dd ?;交互物体mask的句柄
	hBmpInterface24 dd ?	;界面状态的句柄
	hBmpInterfaceM24 dd ?	;界面状态mask的句柄
	hBmpIsland1280 dd ?	;岛屿的句柄
	hBmpIslandM1280 dd ?;岛屿mask的句柄
	hBmpDocks64 dd ?	;码头的句柄
	hBmpDocksM64 dd ?	;码头mask的句柄
	hBmpEffects128 dd ?	;特效的句柄 漩涡 宝箱 闪耀动画
	hBmpEffectsM128 dd ?;特效mask的句柄 漩涡 宝箱 闪耀动画
	hBmpRipple96 dd ?	;水波纹的句柄
	hBmpSandbar256 dd ?	;沙洲的句柄
	hBmpSandbarM256 dd ?;沙洲mask的句柄
	hBmpSurfer64 dd ?	;冲浪者npc的句柄
	hBmpSurferM64 dd ?	;冲浪者npcmask的句柄

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
	items ITEMBMP 5120 dup(<?,?,?,?,?,?>)

	Slowdown struct
		x dd ?			; 初始在屏幕中的x位置
		y dd ?			; 初始在屏幕中的y位置
		w dd ? 			; 在屏幕中绘制的w
		h dd ? 			; 在屏幕中绘制的h
		tp dd ?			; 0~8 9个类型可以选择
		frame dd ?		; 0~2  3个frame可以选择
	Slowdown ends
	slowd Slowdown 10 dup(<?,?,?,?,?,?>) 

	Ambient struct
		x dd ?			; 初始在屏幕中的x位置
		y dd ?			; 初始在屏幕中的y位置
		w dd ? 			; 在屏幕中绘制的w
		h dd ? 			; 在屏幕中绘制的h
		tp dd ?			; 0~3 4个类型可以选择
		frame dd ?		; 0~5 6个frame可以选择
	Ambient ends
	ambi Ambient 4 dup(<?,?,?,?,?,?>)

	Interact struct
		x dd ?			; 初始在屏幕中的x位置
		y dd ?			; 初始在屏幕中的y位置
		w dd ? 			; 在屏幕中绘制的w
		h dd ? 			; 在屏幕中绘制的h
		tp dd ?			; 0~7 8个类型可以选择
		frame dd ?		; 0~3 4个frame可以选择
	Interact ends
	intera Interact 4 dup(<?,?,?,?,?,?>)
	
.code

	;------------------------------------------
	; GetRandom - 获取一个随机数
	; @param left - 随机数的左边界
	; @param right - 随机数的右边界
	; @return 随机数
	;------------------------------------------
	GetRandom PROC left:dword,right:dword
		invoke rand
		xor edx,edx
		mov ebx,right
		sub ebx,left
		div ebx
		add edx,left
		mov eax,edx
		ret
	GetRandom ENDP

	;------------------------------------------
	; LoadAllBmp - 加载所有的图片
	; @param
	; @return void
	;------------------------------------------
	LoadAllBmp PROC
		invoke LoadBitmap, hInstance, IDB_BACK
		mov hBmpBack, eax
		invoke LoadBitmap, hInstance, IDB_WATER
		mov hBmpWater, eax
		invoke LoadBitmap, hInstance, IDB_PLAYER64
		mov hBmpPlayer64, eax
		invoke LoadBitmap, hInstance, IDB_PLAYERM64
		mov hBmpPlayerM64, eax
		invoke LoadBitmap, hInstance, IDB_SURFB64
		mov hBmpSurfB64, eax
		invoke LoadBitmap, hInstance, IDB_SURFBM64
		mov hBmpSurfBM64, eax
		invoke LoadBitmap, hInstance, IDB_SLOWD64
		mov hBmpSlowd64, eax
		invoke LoadBitmap, hInstance, IDB_SLOWDM64
		mov hBmpSlowdM64, eax
		invoke LoadBitmap, hInstance, IDB_AMBIENT64
		mov hBmpAmbient64, eax
		invoke LoadBitmap, hInstance, IDB_AMBIENTM64
		mov hBmpAmbientM64, eax
		invoke LoadBitmap, hInstance, IDB_OBJECTS32
		mov hBmpObjects32, eax
		invoke LoadBitmap, hInstance, IDB_OBJECTSM32
		mov hBmpObjectsM32, eax
		invoke LoadBitmap, hInstance, IDB_OBJECTS64
		mov hBmpObjects64, eax
		invoke LoadBitmap, hInstance, IDB_OBJECTSM64
		mov hBmpObjectsM64, eax
		invoke LoadBitmap, hInstance, IDB_INTERACT64
		mov hBmpInteract64, eax
		invoke LoadBitmap, hInstance, IDB_INTERACTM64
		mov hBmpInteractM64, eax
		invoke LoadBitmap, hInstance, IDB_INTERFACE24
		mov hBmpInterface24, eax
		invoke LoadBitmap, hInstance, IDB_INTERFACEM24
		mov hBmpInterfaceM24, eax
		invoke LoadBitmap, hInstance, IDB_ISLAND1280
		mov hBmpIsland1280, eax
		invoke LoadBitmap, hInstance, IDB_ISLANDM1280
		mov hBmpIslandM1280, eax
		invoke LoadBitmap, hInstance, IDB_DOCKS64
		mov hBmpDocks64, eax
		invoke LoadBitmap, hInstance, IDB_DOCKSM64
		mov hBmpDocksM64, eax
		invoke LoadBitmap, hInstance, IDB_EFFECTS128
		mov hBmpEffects128, eax
		invoke LoadBitmap, hInstance, IDB_EFFECTSM128
		mov hBmpEffectsM128, eax
		invoke LoadBitmap, hInstance, IDB_RIPPLE96
		mov hBmpRipple96, eax
		invoke LoadBitmap, hInstance, IDB_SANDBAR256
		mov hBmpSandbar256, eax
		invoke LoadBitmap, hInstance, IDB_SANDBARM256
		mov hBmpSandbarM256, eax
		invoke LoadBitmap, hInstance, IDB_SURFER64
		mov hBmpSurfer64, eax
		invoke LoadBitmap, hInstance, IDB_SURFERM64
		mov hBmpSurferM64, eax
		ret
	LoadAllBmp ENDP

	;------------------------------------------
	; DeleteBmp - 删除所有的图片
	; @param
	; @return void
	;------------------------------------------
	DeleteBmp PROC
		invoke DeleteObject, hBmpBack
		invoke DeleteObject, hBmpWater
		invoke DeleteObject, hBmpPlayer64
		invoke DeleteObject, hBmpPlayerM64
		invoke DeleteObject, hBmpSurfB64
		invoke DeleteObject, hBmpSurfBM64
		invoke DeleteObject, hBmpSlowd64
		invoke DeleteObject, hBmpSlowdM64
		invoke DeleteObject, hBmpAmbient64
		invoke DeleteObject, hBmpAmbientM64
		invoke DeleteObject, hBmpObjects32
		invoke DeleteObject, hBmpObjectsM32
		invoke DeleteObject, hBmpObjects64
		invoke DeleteObject, hBmpObjectsM64
		invoke DeleteObject, hBmpInteract64
		invoke DeleteObject, hBmpInteractM64
		invoke DeleteObject, hBmpInterface24
		invoke DeleteObject, hBmpInterfaceM24
		invoke DeleteObject, hBmpIsland1280
		invoke DeleteObject, hBmpIslandM1280
		invoke DeleteObject, hBmpDocks64
		invoke DeleteObject, hBmpDocksM64
		invoke DeleteObject, hBmpEffects128
		invoke DeleteObject, hBmpEffectsM128
		invoke DeleteObject, hBmpRipple96
		invoke DeleteObject, hBmpSandbar256
		invoke DeleteObject, hBmpSandbarM256
		invoke DeleteObject, hBmpSurfer64
		invoke DeleteObject, hBmpSurferM64
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
	; UpdateAniTimer - 更新动画的计时器
	; @param
	; @return void
	;------------------------------------------
	UpdateAniTimer PROC uses eax ebx ecx edx esi edi 
		inc aniTimer
		mov eax, aniTimer
		mov edx, 0    ; 清零edx，因为div指令会使用edx:eax作为被除数
		mov ecx, 128    ; 放入ecx，作为除数
		div ecx       ; 执行除法操作，eax = edx:eax / ecx，edx = edx:eax % ecx
		mov aniTimer, edx  ; 将余数（%结果）放回surfBtimer
		xor eax, eax
		ret
	UpdateAniTimer ENDP

	;------------------------------------------
	; UpdateSurfBoard - 更新surfB的句柄
	; @param
	; @return void
	;------------------------------------------
	UpdateSurfBoard PROC uses eax ebx ecx edx esi edi 
		mov ecx, surfer.surfBframe
		mov edx, 0			;被除数的高32位
		mov eax, aniTimer 	;被除数的低32位
		mov ebx, 8			;除数
		div ebx
		cmp edx, 0
		jne UpdateSurfBoardEnd
		inc ecx
		cmp ecx, 3			; 3个frame
		jl UpdateSurfBoardEnd
		mov ecx, 0
		UpdateSurfBoardEnd:
		mov surfer.surfBframe, ecx
		xor eax, eax
		ret
	UpdateSurfBoard ENDP

	;------------------------------------------
	; RenderWater - 绘制水面
	; @param
	; @return void
	;------------------------------------------
	RenderWater PROC uses eax ebx ecx edx esi edi 

		; 画水面
		; -------------
		; | 0 | 1 | 2 |
		; -------------
		; | 3 | 4 | 5 |
		; -------------
		; | 6 | 7 | 8 |
		; -------------

		; 画水面4
		invoke Bmp2Buffer, hBmpWater, water.x, water.y, 768, 768, 0, 0, 768, 768, SRCPAINT
		
		; 画水面7
		mov eax, water.y
		add eax, 768
		invoke Bmp2Buffer, hBmpWater, water.x, eax, 768, 768, 0, 0, 768, 768, SRCPAINT

		; 画水面3
		mov eax, water.x
		sub eax, 768
		invoke Bmp2Buffer, hBmpWater, eax, water.y, 768, 768, 0, 0, 768, 768, SRCPAINT

		; 画水面5
		mov eax, water.x
		add eax, 768
		invoke Bmp2Buffer, hBmpWater, eax, water.y, 768, 768, 0, 0, 768, 768, SRCPAINT

		; 画水面6
		mov eax, water.x
		sub eax, 768
		mov ecx, water.y
		add ecx, 768
		invoke Bmp2Buffer, hBmpWater, eax, ecx, 768, 768, 0, 0, 768, 768, SRCPAINT

		; 画水面8
		mov eax, water.x
		add eax, 768
		mov ecx, water.y
		add ecx, 768
		invoke Bmp2Buffer, hBmpWater, eax, ecx, 768, 768, 0, 0, 768, 768, SRCPAINT
		ret
	RenderWater ENDP

	;------------------------------------------
	; UpdateSpeed - 改变速度
	; @param
	; @return void
	;------------------------------------------
	UpdateSpeed PROC uses eax ebx ecx edx esi edi 
		mov eax, 0
		mov ecx, 0
		.if surfer.action == 0 || surfer.action == 6 || surfer.action == 7 || surfer.action == 8
			mov eax, 0
			mov ecx, 0
		.elseif surfer.action == 1
			add eax, 3
			sub ecx, 3
		.elseif surfer.action == 2
			add eax, 2
			sub ecx, 4
		.elseif surfer.action == 3
			sub ecx, 5
			.if player_state == 1
				mov ecx, 8
			.endif
		.elseif surfer.action == 4
			sub eax, 2
			sub ecx, 4
		.elseif surfer.action == 5
			sub eax, 3
			sub ecx, 3
		.else
			sub ecx, 8
		.endif
		mov speed.x, eax
		mov speed.y, ecx
		ret
	UpdateSpeed ENDP
	
	;------------------------------------------
	; UpdateWater - 更新波浪的位置
	; @param
	; @return void
	;------------------------------------------
	UpdateWater PROC uses eax ebx ecx edx esi edi 
		mov eax, water.x
		mov ecx, water.y
		add eax, speed.x
		add ecx, speed.y
		; 循环恢复
		cmp eax, -752 ; x0 - 768 = 16 - 768
		jg Update1
		mov eax, 16
		Update1:
		cmp eax, 784 ; x0 + 768 = 16 + 768
		jl Update2
		mov eax, 16
		Update2:
		cmp ecx, -852 ; y0 - 768 = -84 - 768
		jg Update3
		mov ecx, -84
		Update3:
		mov water.x, eax 
		mov water.y, ecx
		ret
	UpdateWater ENDP

	;------------------------------------------
	; GetRandPosX - 生成随机的X坐标
	; @param
	; @return void
	;------------------------------------------
	GetRandPosX PROC uses ebx ecx edx esi edi
		; 建议：理解这里的生成随机横坐标逻辑可以画一下图看看
		invoke GetRandom, 0, 17
		shl eax, 6
		.if surfer.action == 3
			mov ecx, -240
		.elseif surfer.action == 1 || surfer.action == 2
			mov ecx, -752
		.elseif surfer.action == 4 || surfer.action == 5
			mov ecx, 272
		.endif
		add ecx, eax
		mov eax, ecx
		ret
	GetRandPosX ENDP
	
	;------------------------------------------
	; GenerateSlowD - 生成slowdown
	; @param
	; @return void
	;------------------------------------------
	GenerateSlowD PROC uses eax ebx ecx edx esi edi
		mov eax, slowdCount
		cmp eax, MAXSLOWD
		jg GenerateSlowdRet
		cmp surfer.action, 0
		je GenerateSlowdRet
		cmp slowdInterval, 0
		jne GenerateSlowdEnd
		; 获得最新的一个Slowd
		mov edi, offset slowd
		mov esi, slowdCount
		imul esi, TYPE Slowdown
		add edi, esi

		; 生成一个slowdown
		; mov esi, 0
		; .while esi < 3 ; 生成3个
			invoke GetRandPosX
			mov (Slowdown PTR [edi]).x, eax
			mov eax, 700
			mov (Slowdown PTR [edi]).y, eax
			mov eax, 64
			mov (Slowdown PTR [edi]).w, eax
			mov eax, 64
			mov (Slowdown PTR [edi]).h, eax
			invoke GetRandom, 0, 8
			mov (Slowdown PTR [edi]).tp, eax
			mov eax, 0
			mov (Slowdown PTR [edi]).frame, eax
			inc slowdCount
			; add edi, TYPE Slowdown
			; inc esi
		; .endw

		invoke GetRandom, 20, 30
		mov slowdInterval, eax
		GenerateSlowdEnd:
			dec slowdInterval
		GenerateSlowdRet:
			xor eax,eax
			ret
	GenerateSlowD ENDP

	;------------------------------------------
	; UpdateSlowD - 更新slowdown的位置
	; @param
	; @return void
	;------------------------------------------
	UpdateSlowD PROC uses eax ebx ecx edx esi edi 
		mov edi, offset slowd
		mov esi, 0
		.while esi < slowdCount
			mov eax, (Slowdown PTR [edi]).x
			mov ecx, (Slowdown PTR [edi]).y
			add eax, speed.x
			add ecx, speed.y
			mov (Slowdown PTR [edi]).x, eax
			mov (Slowdown PTR [edi]).y, ecx
			; if aniTimer % 8 == 0  frame++
			; else 等于之前的帧
			mov ecx, (Slowdown PTR [edi]).frame
			mov edx, 0			;被除数的高32位
			mov eax, aniTimer 	;被除数的低32位
			mov ebx, 8			;除数
			div ebx
			cmp edx, 0
			jne UpdateSlowdEnd
			inc ecx
			cmp ecx, 3
			jl UpdateSlowdEnd
			mov ecx, 0
			UpdateSlowdEnd:

			mov (Slowdown PTR [edi]).frame, ecx
			add edi, TYPE Slowdown
			inc esi
		.endw
		xor eax, eax
		ret
	UpdateSlowD ENDP

	;------------------------------------------
	; RenderSlowd - 绘制slowdown
	; @param
	; @return void
	;------------------------------------------
	RenderSlowd PROC uses eax ebx ecx edx esi edi 
		mov edi, offset slowd
		mov esi, 0
		; 暂时先只是加载一张图片
		.while esi < slowdCount
			mov eax, (Slowdown PTR [edi]).tp
			shl eax, 6
			mov ecx, (Slowdown PTR [edi]).frame
			shl ecx, 6
			invoke Bmp2Buffer, hBmpSlowdM64, \
				(Slowdown PTR [edi]).x, (Slowdown PTR [edi]).y, \
				(Slowdown PTR [edi]).w, (Slowdown PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCAND
			invoke Bmp2Buffer, hBmpSlowd64, \
				(Slowdown PTR [edi]).x, (Slowdown PTR [edi]).y, \
				(Slowdown PTR [edi]).w, (Slowdown PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCPAINT
			add edi, TYPE Slowdown
			inc esi
		.endw
		ret
	RenderSlowd ENDP

	;------------------------------------------
	; RecycleSlowd - 回收slowdown
	; @param
	; @return void
	;------------------------------------------
	RecycleSlowd PROC uses eax ebx ecx edx esi edi
		mov edi, offset slowd
		xor esi, esi
		.while esi < slowdCount
			mov eax, (Slowdown PTR [edi]).y
			add eax, 64
			cmp eax, 0
			jg RecycleSlowdEnd
			; 开始回收，即重新生成
			mov (Slowdown PTR [edi]).y, 700
			invoke GetRandPosX
			mov (Slowdown PTR [edi]).x, eax
			RecycleSlowdEnd:
			inc esi
			add edi, TYPE Slowdown
		.endw
		xor eax,eax
		ret
	RecycleSlowd ENDP

	;------------------------------------------
	; GenerateAmbient - 生成ambient
	; @param
	; @return void
	;------------------------------------------
	GenerateAmbient PROC uses eax ebx ecx edx esi edi
		mov eax, ambiCount
		cmp eax, MAXAMBI
		jg GenerateAmbientRet
		cmp ambiInterval, 0
		jne GenerateAmbientEnd
		; 获得最新的一个Ambient
		mov edi, offset ambi
		mov esi, ambiCount
		imul esi, TYPE Ambient
		add edi, esi

		; 生成一个ambient
		invoke GetRandPosX
		mov (Ambient PTR [edi]).x, eax
		mov eax, 700
		mov (Ambient PTR [edi]).y, eax
		mov eax, 64
		mov (Ambient PTR [edi]).w, eax
		mov eax, 64
		mov (Ambient PTR [edi]).h, eax
		invoke GetRandom, 0, 3
		mov (Ambient PTR [edi]).tp, eax
		mov eax, 0
		mov (Ambient PTR [edi]).frame, eax
		inc ambiCount

		invoke GetRandom, 80, 180
		mov ambiInterval, eax
		GenerateAmbientEnd:
			dec ambiInterval
		GenerateAmbientRet:
			xor eax,eax
			ret
	GenerateAmbient ENDP

	;------------------------------------------
	; UpdateAmbient - 更新ambient的位置
	; @param
	; @return void
	;------------------------------------------
	UpdateAmbient PROC uses eax ebx ecx edx esi edi 
		mov edi, offset ambi
		mov esi, 0
		.while esi < ambiCount
			mov eax, (Ambient PTR [edi]).x
			mov ecx, (Ambient PTR [edi]).y
			add eax, speed.x
			add ecx, speed.y
			mov (Ambient PTR [edi]).x, eax
			mov (Ambient PTR [edi]).y, ecx

			mov eax, (Ambient PTR [edi]).frame
			.if aniTimer == 0
				mov eax, 0
			.elseif aniTimer == 8
				mov eax, 1
			.elseif aniTimer == 16
				mov eax, 2
			.elseif aniTimer == 24
				mov eax, 3
			.elseif aniTimer == 32	
				mov eax, 4
			.elseif aniTimer == 40
				mov eax, 5
			.elseif aniTimer > 40
				mov eax, 5
			.endif
			mov (Ambient PTR [edi]).frame, eax
			add edi, TYPE Ambient
			inc esi
		.endw
		xor eax, eax
		ret
	UpdateAmbient ENDP

	;------------------------------------------
	; RenderAmbient - 绘制ambient
	; @param
	; @return void
	;------------------------------------------
	RenderAmbient PROC uses eax ebx ecx edx esi edi 
		mov edi, offset ambi
		mov esi, 0
		; 暂时先只是加载一张图片
		.while esi < ambiCount
			mov eax, (Ambient PTR [edi]).tp
			shl eax, 6
			mov ecx, (Ambient PTR [edi]).frame
			shl ecx, 6
			invoke Bmp2Buffer, hBmpAmbientM64, \
				(Ambient PTR [edi]).x, (Ambient PTR [edi]).y, \
				(Ambient PTR [edi]).w, (Ambient PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCAND
			invoke Bmp2Buffer, hBmpAmbient64, \
				(Ambient PTR [edi]).x, (Ambient PTR [edi]).y, \
				(Ambient PTR [edi]).w, (Ambient PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCPAINT
			add edi, TYPE Ambient
			inc esi
		.endw
		xor eax, eax
		ret
	RenderAmbient ENDP

	;------------------------------------------
	; RecycleAmbient - 回收ambient
	; @param
	; @return void
	;------------------------------------------
	RecycleAmbient PROC uses eax ebx ecx edx esi edi
		mov edi, offset ambi
		xor esi, esi
		.while esi < ambiCount
			mov eax, (Ambient PTR [edi]).y
			add eax, 64 ; 64是图片的高度
			cmp eax, 0
			jg RecycleAmbientEnd
			; 开始回收，即重新生成
			mov (Ambient PTR [edi]).y, 700
			invoke GetRandPosX
			mov (Ambient PTR [edi]).x, eax
			invoke GetRandom, 0, 3
			mov (Ambient PTR [edi]).tp, eax
			mov eax, 0
			mov (Ambient PTR [edi]).frame, eax
			RecycleAmbientEnd:
			inc esi
			add edi, TYPE Ambient
		.endw
		xor eax,eax
		ret
	RecycleAmbient ENDP

	; ------------------------------------------
	; GenerateInteract - 生成interact
	; @param
	; @return void
	; ------------------------------------------
	GenerateInteract PROC uses eax ebx ecx edx esi edi
		mov eax, interCount
		cmp eax, MAXINTER
		jg GenerateInteractRet
		cmp interInterval, 0
		jne GenerateInteractEnd
		; 获得最新的一个Interact
		mov edi, offset intera
		mov esi, interCount
		imul esi, TYPE Interact
		add edi, esi

		; 生成一个interact
		invoke GetRandPosX
		mov (Interact PTR [edi]).x, eax
		mov eax, 700
		mov (Interact PTR [edi]).y, eax
		mov eax, 64
		mov (Interact PTR [edi]).w, eax
		mov eax, 64
		mov (Interact PTR [edi]).h, eax
		invoke GetRandom, 0, 7
		mov (Interact PTR [edi]).tp, eax
		mov eax, 0
		mov (Interact PTR [edi]).frame, eax
		inc interCount

		invoke GetRandom, 20, 30
		mov interInterval, eax
		GenerateInteractEnd:
			dec interInterval
		GenerateInteractRet:
			xor eax,eax
			ret
	GenerateInteract ENDP

	;------------------------------------------
	; UpdateInteract - 更新interact的位置
	; @param
	; @return void
	;------------------------------------------
	UpdateInteract PROC uses eax ebx ecx edx esi edi 
		mov edi, offset intera
		mov esi, 0
		.while esi < interCount
			mov eax, (Interact PTR [edi]).x
			mov ecx, (Interact PTR [edi]).y
			add eax, speed.x
			add ecx, speed.y
			mov (Interact PTR [edi]).x, eax
			mov (Interact PTR [edi]).y, ecx

			mov ecx, (Interact PTR [edi]).frame
			mov edx, 0			;被除数的高32位
			mov eax, aniTimer 	;被除数的低32位
			mov ebx, 8			;除数
			div ebx
			cmp edx, 0
			jne UpdateInteractEnd
			inc ecx
			cmp ecx, 4			; 4帧
			jl UpdateInteractEnd
			mov ecx, 0
			UpdateInteractEnd:
			mov (Interact PTR [edi]).frame, ecx
			add edi, TYPE Interact
			inc esi
		.endw
		xor eax, eax
		ret
	UpdateInteract ENDP
	
	;------------------------------------------
	; RenderInteract - 绘制interact
	; @param
	; @return void
	;------------------------------------------
	RenderInteract PROC uses eax ebx ecx edx esi edi 
		mov edi, offset intera
		mov esi, 0
		; 暂时先只是加载一张图片
		.while esi < interCount
			mov eax, (Interact PTR [edi]).tp
			shl eax, 6
			mov ecx, (Interact PTR [edi]).frame
			shl ecx, 6
			invoke Bmp2Buffer, hBmpInteractM64, \
				(Interact PTR [edi]).x, (Interact PTR [edi]).y, \
				(Interact PTR [edi]).w, (Interact PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCAND
			invoke Bmp2Buffer, hBmpInteract64, \
				(Interact PTR [edi]).x, (Interact PTR [edi]).y, \
				(Interact PTR [edi]).w, (Interact PTR [edi]).h, \
				eax, ecx, \
				64, 64, \
				SRCPAINT
			add edi, TYPE Interact
			inc esi
		.endw
		xor eax, eax
		ret
	RenderInteract ENDP

	;------------------------------------------
	; RecycleInteract - 回收interact
	; @param
	; @return void
	;------------------------------------------
	RecycleInteract PROC uses eax ebx ecx edx esi edi
		mov edi, offset intera
		xor esi, esi
		.while esi < interCount
			mov eax, (Interact PTR [edi]).y
			add eax, 64 ; 64是图片的高度
			cmp eax, 0
			jg RecycleInteractEnd
			; 开始回收，即重新生成
			mov (Interact PTR [edi]).y, 700
			invoke GetRandPosX
			mov (Interact PTR [edi]).x, eax
			invoke GetRandom, 0, 7
			mov (Interact PTR [edi]).tp, eax
			mov eax, 0
			mov (Interact PTR [edi]).frame, eax
			RecycleInteractEnd:
			inc esi
			add edi, TYPE Interact
		.endw
		xor eax,eax
		ret
	RecycleInteract ENDP

	;------------------------------------------
	; RenderTest - 测试用
	; @param
	; @return void
	;------------------------------------------
	RenderTest PROC uses eax ebx ecx edx esi edi
		; invoke Bmp2Buffer, hBmpObjectsM32, 0, 0, 640, 32, 0, 0, 640, 32, SRCAND
		; invoke Bmp2Buffer, hBmpObjects32, 0, 0, 640, 32, 0, 0, 640, 32, SRCPAINT
		invoke Bmp2Buffer, hBmpInteractM64, 0, 0, 512, 256, 0, 0, 512, 256, SRCAND
		invoke Bmp2Buffer, hBmpInteract64, 0, 0, 512, 256, 0, 0, 512, 256, SRCPAINT
		; invoke Bmp2Buffer, hBmpInterfaceM24, 0, 0, 48, 96, 0, 0, 48, 96, SRCAND
		; invoke Bmp2Buffer, hBmpInterface24, 0, 0, 48, 96, 0, 0, 48, 96, SRCPAINT
		; invoke Bmp2Buffer, hBmpIslandM1280, 0, 0, 1280, 512, 0, 0, 1280, 512, SRCAND
		; invoke Bmp2Buffer, hBmpIsland1280, 0, 0, 1280, 512, 0, 0, 1280, 512, SRCPAINT
		; invoke Bmp2Buffer, hBmpDocksM64, 0, 0, 640, 64, 0, 0, 640, 64, SRCAND
		; invoke Bmp2Buffer, hBmpDocks64, 0, 0, 640, 64, 0, 0, 640, 64, SRCPAINT
		; invoke Bmp2Buffer, hBmpEffectsM128, 0, 0, 768, 384, 0, 0, 768, 384, SRCAND
		; invoke Bmp2Buffer, hBmpEffects128, 0, 0, 768, 384, 0, 0, 768, 384, SRCPAINT
		; invoke Bmp2Buffer, hBmpRipple96, 0, 0, 96, 288, 0, 0, 96, 288, SRCPAINT
		; invoke Bmp2Buffer, hBmpSandbarM256, 0, 0, 1024, 128, 0, 0, 1024, 128, SRCAND
		; invoke Bmp2Buffer, hBmpSandbar256, 0, 0, 1024, 128, 0, 0, 1024, 128, SRCPAINT
		; invoke Bmp2Buffer, hBmpSurferM64, 0, 0, 1728, 128, 0, 0, 1728, 128, SRCAND
		; invoke Bmp2Buffer, hBmpSurfer64, 0, 0, 1728, 128, 0, 0, 1728, 128, SRCPAINT
		xor eax, eax
		ret
	RenderTest ENDP
	
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
			; invoke RenderTest
			invoke RenderWater
			invoke RenderAmbient
			invoke RenderSlowd
			invoke RenderInteract
			invoke RenderSurfer
			invoke Buffer2Window
		.elseif uMsg ==WM_TIMER ;刷新
			invoke InvalidateRect,hWnd,NULL,FALSE
			invoke UpdateSpeed
			invoke UpdateAniTimer
			invoke UpdateSurfBoard

			invoke UpdateWater

			invoke GenerateSlowD
			invoke UpdateSlowD
			.if slowdCount > 2
				invoke RecycleSlowd
			.endif

			invoke GenerateAmbient
			invoke UpdateAmbient
			.if ambiCount > 1
				invoke RecycleAmbient
			.endif

			invoke GenerateInteract
			invoke UpdateInteract
			.if interCount > 1
				invoke RecycleInteract
			.endif
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
				100,100,1312,784,\
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
