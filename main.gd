extends Node2D

# ---------------------------------------------------------
# CONFIGURAÇÕES GERAIS
# ---------------------------------------------------------
var tela_tamanho = Vector2(1152, 648) 
var jogo_rodando = false
var vidas = 3
var acertos_totais = 0

var velocidade_inicial = 180
var velocidade_silaba = 180 
var distancia_entre_silabas = 470.0 

var fonte_jogo = FontVariation.new()

# ---------------------------------------------------------
# DICIONÁRIO LOCAL E CONFIGURAÇÃO SÍLABAS
# ---------------------------------------------------------
var todas_silabas = ["A", "BA", "CA", "DA", "FA", "GA", "JA", "LA", "MA", "NA", "PA", "QUA", "RA", "SA", "TA", "VA", "XA", "ZA"]
var palavras_disponiveis = [] 

var dicionario_local = {
	"aviao": ["A", "VIÃO"], "banana": ["BA", "NANA"], "cachorro": ["CA", "CHORRO"],
	"dado": ["DA", "DO"], "faca": ["FA", "CA"], "gato": ["GA", "TO"],
	"jacare": ["JA", "CARÉ"], "lapis": ["LA", "PIS"], "macaco": ["MA", "CACO"],
	"navio": ["NA", "VIO"], "pato": ["PA", "TO"], "quati": ["QUA", "TI"],
	"rato": ["RA", "TO"], "sapo": ["SA", "PO"], "tatu": ["TA", "TU"],
	"vaca": ["VA", "CA"], "xadrez": ["XA", "DREZ"], "zabumba": ["ZA", "BUMBA"]
}

# ---------------------------------------------------------
# VARIÁVEIS DO JOGO E REFERÊNCIAS
# ---------------------------------------------------------
var palavra_atual = ""
var silaba_alvo = ""
var restante_palavra = ""
var silabas_coletadas = []
var silabas_em_cena = []

var padrao_spawn = [false, false, true, false, true]
var contador_spawn = 0
var video_terminou = false 

var fundo_floresta: TextureRect
var lbl_titulo: Label
var btn_iniciar: Button
var coracoes: Array[TextureRect] = [] 
var img_palavra_alvo: TextureRect
var lbl_palavra_alvo: Label 
var lbl_palavra_formada: Label
var area_pesca: Area2D
var timer_spawn: Timer
var vara_pesca: TextureRect
var btn_pausa: Button
var lbl_pausa: Label
var lbl_tutorial: Label 

var btn_continuar: Button
var btn_voltar_menu: Button

var video_intro: VideoStreamPlayer
var audio_silaba: AudioStreamPlayer
var audio_bgm: AudioStreamPlayer
var audio_sfx: AudioStreamPlayer 
var audio_voz: AudioStreamPlayer

var vara_posicao_original = Vector2.ZERO
var vara_posicao_animada = Vector2.ZERO
var vara_em_animacao = false

var menu_lateral_layer: CanvasLayer
var painel_lateral: Panel
var btn_volume: TextureButton
var btn_sair: TextureButton
var slider_volume: VSlider

func _ready():
	var fonte_base = load("res://fontes/fonte.ttf")
	if fonte_base:
		fonte_jogo.base_font = fonte_base
		fonte_jogo.variation_embolden = 0.1

	configurar_audios()
	construir_cenario_e_ui()
	construir_menu_lateral()
	construir_zona_pesca()
	
	timer_spawn = Timer.new()
	timer_spawn.timeout.connect(_on_timer_spawn_timeout)
	add_child(timer_spawn)
	
	iniciar_intro_video()

# ---------------------------------------------------------
# SISTEMA DE ÁUDIO
# ---------------------------------------------------------
func configurar_audios():
	audio_bgm = AudioStreamPlayer.new()
	var musica = load("res://audios/musica_fundo.mp3")
	if musica:
		if musica is AudioStreamMP3:
			musica.loop = true
		audio_bgm.stream = musica
		audio_bgm.volume_db = -12.0
	add_child(audio_bgm)
	
	audio_silaba = AudioStreamPlayer.new()
	audio_silaba.volume_db = 2.0
	add_child(audio_silaba)
	
	audio_sfx = AudioStreamPlayer.new()
	add_child(audio_sfx)
	
	audio_voz = AudioStreamPlayer.new()
	audio_voz.volume_db = 2.0 
	audio_voz.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio_voz)

func tocar_sfx(nome_arquivo: String, volume_ajuste: float = 0.0):
	var som = load("res://audios/" + nome_arquivo)
	if som:
		audio_sfx.stream = som
		audio_sfx.volume_db = volume_ajuste
		audio_sfx.play()

func tocar_som_silaba(silaba_texto: String):
	var caminho_base = "res://audios/" + silaba_texto.to_lower()
	var stream_audio = _carregar_audio_inteligente(caminho_base)
	if stream_audio:
		audio_silaba.stream = stream_audio
		audio_silaba.play()

func tocar_voz(nome_arquivo: String):
	var caminho_base = "res://audios/" + nome_arquivo
	var stream_audio = _carregar_audio_inteligente(caminho_base)
	if stream_audio:
		audio_voz.stream = stream_audio
		audio_voz.play()

func _carregar_audio_inteligente(caminho_base: String):
	if ResourceLoader.exists(caminho_base + ".wav"): return load(caminho_base + ".wav")
	elif ResourceLoader.exists(caminho_base + ".mp3"): return load(caminho_base + ".mp3")
	elif ResourceLoader.exists(caminho_base + ".ogg"): return load(caminho_base + ".ogg")
	return null

# ---------------------------------------------------------
# SISTEMA DE INTRODUÇÃO
# ---------------------------------------------------------
func iniciar_intro_video():
	btn_iniciar.hide() 
	var camada_video = CanvasLayer.new()
	camada_video.name = "CamadaVideo"
	camada_video.layer = 120 
	add_child(camada_video)
	
	video_intro = VideoStreamPlayer.new()
	var stream_video = load("res://videos/intro.ogv")
	if stream_video:
		video_intro.stream = stream_video
		video_intro.expand = true 
		video_intro.set_anchors_preset(Control.PRESET_FULL_RECT) 
		video_intro.autoplay = true 
		video_intro.finished.connect(_on_video_intro_finished)
		camada_video.add_child(video_intro)
	else:
		_on_video_intro_finished()

func _on_video_intro_finished():
	if has_node("CamadaVideo"):
		var cv = get_node("CamadaVideo")
		cv.queue_free()
	
	if audio_bgm.stream: audio_bgm.play()
	lbl_palavra_alvo.hide()
	btn_iniciar.show()

# ---------------------------------------------------------
# CONSTRUÇÃO DA INTERFACE E MENU LATERAL
# ---------------------------------------------------------
func aplicar_estilo_botao(btn: Button, estilo_normal, estilo_hover, estilo_pressed):
	btn.focus_mode = Control.FOCUS_NONE 
	btn.add_theme_stylebox_override("normal", estilo_normal)
	btn.add_theme_stylebox_override("hover", estilo_hover)
	btn.add_theme_stylebox_override("pressed", estilo_pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	btn.add_theme_color_override("font_hover_outline_color", Color(0, 0, 0))
	btn.add_theme_color_override("font_pressed_outline_color", Color(0, 0, 0))
	btn.add_theme_constant_override("outline_size", 8)
	if fonte_jogo.base_font: btn.add_theme_font_override("font", fonte_jogo)

func construir_menu_lateral():
	menu_lateral_layer = CanvasLayer.new()
	menu_lateral_layer.layer = 110 
	add_child(menu_lateral_layer)

	painel_lateral = Panel.new()
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1) 
	estilo.border_color = Color(0, 0, 0) 
	estilo.border_width_left = 4; estilo.border_width_top = 4; estilo.border_width_right = 4; estilo.border_width_bottom = 4
	estilo.corner_radius_top_left = 30; estilo.corner_radius_bottom_left = 30; estilo.corner_radius_top_right = 30; estilo.corner_radius_bottom_right = 30
	
	painel_lateral.add_theme_stylebox_override("panel", estilo)
	painel_lateral.size = Vector2(70, 180)
	painel_lateral.position = Vector2(10, (tela_tamanho.y / 2) - 90)
	menu_lateral_layer.add_child(painel_lateral)

	btn_volume = TextureButton.new()
	btn_volume.focus_mode = Control.FOCUS_NONE
	btn_volume.custom_minimum_size = Vector2(40, 40); btn_volume.size = Vector2(40, 40); btn_volume.ignore_texture_size = true; btn_volume.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_volume.position = Vector2(15, 20); btn_volume.mouse_entered.connect(_on_volume_hover_enter); atualizar_icone_volume(true)
	painel_lateral.add_child(btn_volume)

	slider_volume = VSlider.new()
	slider_volume.focus_mode = Control.FOCUS_NONE
	slider_volume.size = Vector2(30, 130); slider_volume.position = Vector2(70, 25); slider_volume.value = 100; slider_volume.hide()
	slider_volume.value_changed.connect(_on_volume_changed); painel_lateral.add_child(slider_volume)

	btn_sair = TextureButton.new()
	btn_sair.focus_mode = Control.FOCUS_NONE
	btn_sair.custom_minimum_size = Vector2(40, 40); btn_sair.size = Vector2(40, 40); btn_sair.ignore_texture_size = true; btn_sair.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_sair.position = Vector2(15, 115); btn_sair.pressed.connect(func(): get_tree().quit())
	btn_sair.texture_normal = load("res://icones/sair.png")
	painel_lateral.add_child(btn_sair)

func _on_volume_hover_enter():
	slider_volume.show()
	var tween = get_tree().create_tween()
	tween.tween_property(painel_lateral, "size:x", 120.0, 0.2)

func _on_volume_changed(valor):
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, valor == 0)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor / 100.0))
	atualizar_icone_volume(valor > 0)

func atualizar_icone_volume(com_som: bool):
	var tex = load("res://icones/volume.png") if com_som else load("res://icones/mutado.png")
	if tex: btn_volume.texture_normal = tex

func construir_cenario_e_ui():
	fundo_floresta = TextureRect.new()
	fundo_floresta.size = tela_tamanho; fundo_floresta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fundo_floresta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo_floresta.texture = load("res://imagens/fundo_floresta.png")
	add_child(fundo_floresta)
	
	lbl_titulo = Label.new(); lbl_titulo.text = "PESCA-SÍLABAS"; lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_titulo.add_theme_font_size_override("font_size", 50); lbl_titulo.add_theme_color_override("font_color", Color(1, 1, 0)); lbl_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lbl_titulo.add_theme_constant_override("outline_size", 10) 
	lbl_titulo.position = Vector2(tela_tamanho.x - 480, 20); lbl_titulo.size = Vector2(450, 60)
	if fonte_jogo.base_font: lbl_titulo.add_theme_font_override("font", fonte_jogo)
	add_child(lbl_titulo)
	
	var container_vidas = HBoxContainer.new()
	container_vidas.position = Vector2(100, 20)
	container_vidas.add_theme_constant_override("separation", 10)
	add_child(container_vidas)
	
	var tex_coracao = load("res://icones/coracao.png")
	for i in range(3):
		var coracao_img = TextureRect.new()
		coracao_img.custom_minimum_size = Vector2(45, 45)
		coracao_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coracao_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tex_coracao:
			coracao_img.texture = tex_coracao
		container_vidas.add_child(coracao_img)
		coracoes.append(coracao_img)
		
	var estilo_botao = StyleBoxFlat.new(); estilo_botao.bg_color = Color(1.0, 0.55, 0.1); estilo_botao.corner_radius_top_left = 30; estilo_botao.corner_radius_bottom_left = 30; estilo_botao.corner_radius_top_right = 30; estilo_botao.corner_radius_bottom_right = 30
	estilo_botao.border_width_left = 4; estilo_botao.border_width_top = 4; estilo_botao.border_width_right = 4; estilo_botao.border_width_bottom = 10; estilo_botao.border_color = Color(0.2, 0.1, 0.0) 
	var estilo_hover = estilo_botao.duplicate(); estilo_hover.bg_color = Color(1.0, 0.65, 0.25)
	var estilo_pressionado = estilo_botao.duplicate(); estilo_pressionado.border_width_bottom = 4; estilo_pressionado.bg_color = Color(0.9, 0.45, 0.05)
	
	btn_iniciar = Button.new(); btn_iniciar.text = "INICIAR JOGO"; btn_iniciar.add_theme_font_size_override("font_size", 40); btn_iniciar.size = Vector2(300, 100); btn_iniciar.position = Vector2((tela_tamanho.x - 300) / 2, (tela_tamanho.y - 100) / 2)
	aplicar_estilo_botao(btn_iniciar, estilo_botao, estilo_hover, estilo_pressionado)
	btn_iniciar.mouse_entered.connect(func(): tocar_voz("voz_iniciar"))
	btn_iniciar.pressed.connect(iniciar_jogo); add_child(btn_iniciar); btn_iniciar.hide()
	
	img_palavra_alvo = TextureRect.new(); img_palavra_alvo.size = Vector2(180, 180); img_palavra_alvo.position = Vector2((tela_tamanho.x / 2) - 90, 30); img_palavra_alvo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img_palavra_alvo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; img_palavra_alvo.hide(); add_child(img_palavra_alvo)
	
	lbl_palavra_alvo = Label.new(); lbl_palavra_alvo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_palavra_alvo.add_theme_font_size_override("font_size", 80); lbl_palavra_alvo.add_theme_color_override("font_outline_color", Color(0,0,0)); lbl_palavra_alvo.add_theme_constant_override("outline_size", 8); lbl_palavra_alvo.size = Vector2(tela_tamanho.x, 100)
	lbl_palavra_alvo.position = Vector2(0, (tela_tamanho.y / 2) - 80)
	if fonte_jogo.base_font: lbl_palavra_alvo.add_theme_font_override("font", fonte_jogo); lbl_palavra_alvo.hide(); add_child(lbl_palavra_alvo)
	
	lbl_palavra_formada = Label.new(); lbl_palavra_formada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_palavra_formada.add_theme_font_size_override("font_size", 60); lbl_palavra_formada.add_theme_color_override("font_color", Color(0.5, 1, 0.5)); lbl_palavra_formada.add_theme_color_override("font_outline_color", Color(0,0,0)); lbl_palavra_formada.add_theme_constant_override("outline_size", 6); lbl_palavra_formada.position = Vector2(tela_tamanho.x / 2 - 200, 220); lbl_palavra_formada.size = Vector2(400, 100)
	if fonte_jogo.base_font: lbl_palavra_formada.add_theme_font_override("font", fonte_jogo); lbl_palavra_formada.hide(); add_child(lbl_palavra_formada)
	
	btn_pausa = Button.new(); btn_pausa.text = "PAUSAR"; btn_pausa.add_theme_font_size_override("font_size", 25); btn_pausa.size = Vector2(150, 50); btn_pausa.position = Vector2(tela_tamanho.x - 180, 90); btn_pausa.process_mode = Node.PROCESS_MODE_ALWAYS 
	aplicar_estilo_botao(btn_pausa, estilo_botao, estilo_hover, estilo_pressionado)
	btn_pausa.mouse_entered.connect(func(): tocar_voz("voz_voltar") if get_tree().paused else tocar_voz("voz_pausar"))
	btn_pausa.pressed.connect(alternar_pausa); btn_pausa.hide(); add_child(btn_pausa)
	
	lbl_pausa = Label.new(); lbl_pausa.text = "JOGO PAUSADO"; lbl_pausa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_pausa.add_theme_font_size_override("font_size", 90); lbl_pausa.add_theme_color_override("font_color", Color(1, 0.8, 0)); lbl_pausa.add_theme_color_override("font_outline_color", Color(0,0,0)); lbl_pausa.add_theme_constant_override("outline_size", 8); lbl_pausa.position = Vector2(0, (tela_tamanho.y / 2) - 80); lbl_pausa.size = Vector2(tela_tamanho.x, 100)
	if fonte_jogo.base_font: lbl_pausa.add_theme_font_override("font", fonte_jogo); lbl_pausa.hide(); add_child(lbl_pausa)
	
	btn_continuar = Button.new(); btn_continuar.text = "CONTINUAR"; btn_continuar.add_theme_font_size_override("font_size", 30); btn_continuar.size = Vector2(250, 80); btn_continuar.position = Vector2(tela_tamanho.x/2 - 270, tela_tamanho.y/2 + 50)
	btn_continuar.focus_mode = Control.FOCUS_NONE
	aplicar_estilo_botao(btn_continuar, estilo_botao, estilo_hover, estilo_pressionado)
	btn_continuar.mouse_entered.connect(func(): tocar_voz("voz_continuar"))
	btn_continuar.pressed.connect(acao_continuar); add_child(btn_continuar); btn_continuar.hide()
	
	btn_voltar_menu = Button.new(); btn_voltar_menu.text = "MENU INICIAL"; btn_voltar_menu.add_theme_font_size_override("font_size", 30); btn_voltar_menu.size = Vector2(250, 80); btn_voltar_menu.position = Vector2(tela_tamanho.x/2 + 20, tela_tamanho.y/2 + 50)
	btn_voltar_menu.focus_mode = Control.FOCUS_NONE
	aplicar_estilo_botao(btn_voltar_menu, estilo_botao, estilo_hover, estilo_pressionado)
	btn_voltar_menu.mouse_entered.connect(func(): tocar_voz("voz_menu_inicial"))
	btn_voltar_menu.pressed.connect(acao_voltar_menu); add_child(btn_voltar_menu); btn_voltar_menu.hide()

	lbl_tutorial = Label.new()
	lbl_tutorial.text = "APERTE [ ESPAÇO ] PARA PESCAR!"
	lbl_tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tutorial.add_theme_font_size_override("font_size", 45)
	lbl_tutorial.add_theme_color_override("font_color", Color(1, 1, 0)) 
	lbl_tutorial.add_theme_color_override("font_outline_color", Color(0,0,0))
	lbl_tutorial.add_theme_constant_override("outline_size", 8)
	lbl_tutorial.position = Vector2(0, tela_tamanho.y - 180) 
	lbl_tutorial.size = Vector2(tela_tamanho.x, 60)
	
	lbl_tutorial.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_tutorial.mouse_entered.connect(func(): tocar_voz("voz_tutorial"))
	
	if fonte_jogo.base_font: lbl_tutorial.add_theme_font_override("font", fonte_jogo)
	lbl_tutorial.hide()
	add_child(lbl_tutorial)
	
	var tween_tutorial = get_tree().create_tween().bind_node(lbl_tutorial).set_loops()
	tween_tutorial.tween_property(lbl_tutorial, "modulate:a", 0.2, 0.8)
	tween_tutorial.tween_property(lbl_tutorial, "modulate:a", 1.0, 0.8)

func construir_zona_pesca():
	vara_pesca = TextureRect.new()
	vara_pesca.texture = load("res://imagens/vara_pesca.png")
	vara_pesca.size = Vector2(450, 150); vara_pesca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; vara_pesca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vara_posicao_original = Vector2(tela_tamanho.x / 2 - 56, tela_tamanho.y - 500); vara_posicao_animada = vara_posicao_original + Vector2(0, 50); vara_pesca.position = vara_posicao_original; add_child(vara_pesca); vara_pesca.hide() 
	area_pesca = Area2D.new(); area_pesca.position = Vector2(tela_tamanho.x / 2, tela_tamanho.y - 100); var formato = CollisionShape2D.new(); var retangulo = RectangleShape2D.new(); retangulo.size = Vector2(150, 150); formato.shape = retangulo; area_pesca.add_child(formato); add_child(area_pesca)

# ---------------------------------------------------------
# LÓGICA DO JOGO E DA PAUSA
# ---------------------------------------------------------
func iniciar_jogo():
	get_tree().paused = false
	btn_iniciar.hide()
	lbl_palavra_formada.show()
	vara_pesca.show() 
	btn_pausa.show()
	lbl_tutorial.show()
	
	vidas = 3
	acertos_totais = 0
	velocidade_silaba = velocidade_inicial
	
	atualizar_coracoes()
	limpar_silabas_da_tela()
	sortear_nova_palavra()
	
	jogo_rodando = true
	timer_spawn.wait_time = distancia_entre_silabas / float(velocidade_silaba) 
	timer_spawn.start()

func alternar_pausa():
	if not jogo_rodando: return 
	get_tree().paused = !get_tree().paused
	btn_pausa.text = "VOLTAR" if get_tree().paused else "PAUSAR"
	lbl_pausa.visible = get_tree().paused; img_palavra_alvo.visible = !get_tree().paused; lbl_palavra_formada.visible = !get_tree().paused
	
	if get_tree().paused:
		tocar_voz("voz_jogo_pausado")

func sortear_nova_palavra():
	silabas_coletadas.clear()
	contador_spawn = 0 
	
	if palavras_disponiveis.size() == 0:
		palavras_disponiveis = dicionario_local.keys().duplicate()
		palavras_disponiveis.shuffle()
		
	palavra_atual = palavras_disponiveis.pop_front()
	silaba_alvo = dicionario_local[palavra_atual][0]
	restante_palavra = dicionario_local[palavra_atual][1]
	
	var carregou = false
	var extensoes = [".png", ".jpg", ".jpeg"]
	for ext in extensoes:
		var path = "res://imagens/" + palavra_atual + ext
		if ResourceLoader.exists(path):
			img_palavra_alvo.texture = load(path)
			carregou = true
			break
	
	if not carregou: print("AVISO: Imagem local não encontrada para: " + palavra_atual)
	img_palavra_alvo.show()
	atualizar_textos()

func atualizar_textos():
	if silabas_coletadas.size() == 0:
		lbl_palavra_formada.text = "[ _ ] " + restante_palavra
	else:
		lbl_palavra_formada.text = silaba_alvo + restante_palavra 

func atualizar_coracoes():
	for i in range(coracoes.size()): coracoes[i].visible = i < vidas

# ---------------------------------------------------------
# CRIAÇÃO E MOVIMENTO DAS SÍLABAS
# ---------------------------------------------------------
func _on_timer_spawn_timeout():
	if not jogo_rodando or silabas_coletadas.size() > 0: return
	var texto_spawn = silaba_alvo if padrao_spawn[contador_spawn % padrao_spawn.size()] else todas_silabas[randi() % todas_silabas.size()]
	while not padrao_spawn[contador_spawn % padrao_spawn.size()] and texto_spawn == silaba_alvo:
		texto_spawn = todas_silabas[randi() % todas_silabas.size()]
	contador_spawn += 1; criar_silaba_na_tela(texto_spawn)

func criar_silaba_na_tela(texto: String):
	var silaba_area = Area2D.new(); silaba_area.add_to_group("silaba"); var fundo = Panel.new(); fundo.name = "Fundo"; var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(1, 0.9, 0.2); estilo.corner_radius_top_left = 15; estilo.corner_radius_top_right = 15; estilo.corner_radius_bottom_left = 15; estilo.corner_radius_bottom_right = 15
	estilo.border_width_left = 4; estilo.border_width_top = 4; estilo.border_width_right = 4; estilo.border_width_bottom = 4; estilo.border_color = Color(0, 0, 0)
	fundo.add_theme_stylebox_override("panel", estilo); fundo.size = Vector2(100, 80); fundo.position = Vector2(-50, -40); silaba_area.add_child(fundo)
	var lbl_silaba = Label.new(); lbl_silaba.name = "Label"; lbl_silaba.text = texto; lbl_silaba.set_meta("texto_real", texto); lbl_silaba.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_silaba.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_silaba.add_theme_font_size_override("font_size", 40); lbl_silaba.add_theme_color_override("font_color", Color(0, 0, 0)); lbl_silaba.size = Vector2(100, 80); lbl_silaba.position = Vector2(-50, -40)
	if fonte_jogo.base_font: lbl_silaba.add_theme_font_override("font", fonte_jogo)
	silaba_area.add_child(lbl_silaba); var col = CollisionShape2D.new(); var shape = RectangleShape2D.new(); shape.size = Vector2(100, 80); col.shape = shape; silaba_area.add_child(col)
	silaba_area.position = Vector2(tela_tamanho.x + 100, tela_tamanho.y - 100); add_child(silaba_area); silabas_em_cena.append(silaba_area)

func limpar_silabas_da_tela():
	for s in silabas_em_cena: if is_instance_valid(s): s.queue_free()
	silabas_em_cena.clear()

func _process(delta):
	if slider_volume != null and slider_volume.visible:
		var mp = painel_lateral.get_local_mouse_position()
		if not Rect2(0, 0, 130, 180).has_point(mp):
			slider_volume.hide(); var tw = get_tree().create_tween(); tw.tween_property(painel_lateral, "size:x", 70.0, 0.2)

	if not jogo_rodando: return
	
	for i in range(silabas_em_cena.size() - 1, -1, -1):
		var s = silabas_em_cena[i]
		if is_instance_valid(s):
			s.position.x -= velocidade_silaba * delta
			if s.position.x < -150: s.queue_free(); silabas_em_cena.remove_at(i)

# ---------------------------------------------------------
# INTERAÇÃO DO JOGADOR E ACERTOS
# ---------------------------------------------------------
func _input(event):
	if get_tree().paused: return 
	if event.is_action_pressed("ui_accept"):
		if jogo_rodando and not vara_em_animacao:
			lbl_tutorial.hide()
			tocar_sfx("som_vara.mp3", -2.0); comecar_animacao_vara(); tentar_pescar()
		elif btn_iniciar.visible: iniciar_jogo()

func comecar_animacao_vara():
	vara_em_animacao = true; var tween = get_tree().create_tween(); tween.tween_property(vara_pesca, "position", vara_posicao_animada, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(vara_pesca, "position", vara_posicao_original, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT); tween.finished.connect(func(): vara_em_animacao = false)

func tentar_pescar():
	var areas_capturadas = area_pesca.get_overlapping_areas()
	
	for area in areas_capturadas:
		if area.is_in_group("silaba"):
			var texto_pescado = area.get_node("Label").get_meta("texto_real")
			
			tocar_som_silaba(texto_pescado) 
			
			if texto_pescado == silaba_alvo:
				tocar_sfx("som_acerto.wav", -6.0)
				
				silabas_coletadas.append(texto_pescado)
				animar_captura(area, true) 
				atualizar_textos()
				
				acertos_totais += 1
				velocidade_silaba += 50 
				
				if vidas < 3:
					vidas += 1
					atualizar_coracoes()
				
				jogo_rodando = false 
				timer_spawn.stop()
				
				await get_tree().create_timer(0.8).timeout
				
				var nome_voz = palavra_atual.to_lower().replace("ã", "a").replace("é", "e").replace("á", "a")
				tocar_voz("voz_" + nome_voz)
				
				await get_tree().create_timer(1.5).timeout
				
				if acertos_totais >= 3:
					vitoria_jogo()
				else:
					iniciar_proxima_palavra()
					
				break
			else:
				tocar_sfx("som_erro.mp3", -6.0)
				animar_captura(area, false) 
				perder_vida()
				break

func animar_captura(area: Area2D, correta: bool):
	area.remove_from_group("silaba"); if silabas_em_cena.has(area): silabas_em_cena.erase(area)
	var fundo = area.get_node("Fundo") as Panel; var estilo = fundo.get_theme_stylebox("panel").duplicate(); fundo.add_theme_stylebox_override("panel", estilo)
	estilo.bg_color = Color(0.2, 0.8, 0.2) if correta else Color(0.9, 0.2, 0.2)
	var tween = get_tree().create_tween(); tween.tween_property(area, "scale", Vector2(1.2, 1.2), 0.15)
	tween.parallel().tween_property(area, "modulate:a", 0.0, 0.3); tween.finished.connect(func(): area.queue_free())

func iniciar_proxima_palavra():
	limpar_silabas_da_tela()
	sortear_nova_palavra()
	jogo_rodando = true
	timer_spawn.wait_time = distancia_entre_silabas / float(velocidade_silaba)
	timer_spawn.start()

func perder_vida():
	vidas -= 1; atualizar_coracoes(); if vidas <= 0: game_over()

func vitoria_jogo():
	limpar_silabas_da_tela(); vara_pesca.hide(); btn_pausa.hide()
	img_palavra_alvo.hide(); lbl_palavra_formada.hide()
	lbl_tutorial.hide()
	
	tocar_sfx("som_nivel_up.wav", -4.0)
	tocar_voz("voz_voce_venceu")
	
	lbl_palavra_alvo.text = "VOCÊ VENCEU!"; lbl_palavra_alvo.position = Vector2(0, (tela_tamanho.y / 2) - 80) 
	lbl_palavra_alvo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_palavra_alvo.add_theme_color_override("font_color", Color(0, 1, 0)); lbl_palavra_alvo.show()
	btn_continuar.show(); btn_voltar_menu.show()
	acertos_totais = 0; velocidade_silaba = velocidade_inicial

func game_over():
	jogo_rodando = false
	timer_spawn.stop()
	btn_pausa.hide()
	img_palavra_alvo.hide()
	lbl_palavra_formada.hide()
	vara_pesca.hide()
	lbl_tutorial.hide()
	
	await get_tree().create_timer(1.5).timeout
	
	limpar_silabas_da_tela()
	tocar_voz("voz_tente_novamente")
	
	lbl_palavra_alvo.text = "TENTE NOVAMENTE!"
	lbl_palavra_alvo.add_theme_color_override("font_color", Color(1, 0.5, 0))
	lbl_palavra_alvo.position = Vector2(0, (tela_tamanho.y / 2) - 80) 
	lbl_palavra_alvo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
	lbl_palavra_alvo.show()
	
	await get_tree().create_timer(3.0).timeout
	
	lbl_palavra_alvo.hide(); lbl_palavra_alvo.add_theme_color_override("font_color", Color(1, 1, 1)); btn_iniciar.show()

# ---------------------------------------------------------
# AÇÕES DOS BOTÕES FINAIS
# ---------------------------------------------------------
func acao_continuar():
	lbl_palavra_alvo.hide(); lbl_palavra_alvo.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_continuar.hide(); btn_voltar_menu.hide()
	iniciar_proxima_palavra()
	vara_pesca.show(); btn_pausa.show()
	lbl_tutorial.show()

func acao_voltar_menu():
	lbl_palavra_alvo.hide(); lbl_palavra_alvo.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_continuar.hide(); btn_voltar_menu.hide(); img_palavra_alvo.hide(); lbl_palavra_formada.hide()
	palavras_disponiveis.clear() 
	btn_iniciar.show()
