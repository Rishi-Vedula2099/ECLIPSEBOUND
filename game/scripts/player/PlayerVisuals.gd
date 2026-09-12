# PlayerVisuals.gd
# Crisp 2D pixel-art drawing for player character, weapon animations, and effects.
class_name PlayerVisuals
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")

@onready var player = get_parent()

# Palette Colors (from art guidelines)
const COLOR_COAT: Color = Color("#8b1e2b")       # Crimson Red Dante Coat
const COLOR_HAIR: Color = Color("#e2e8f0")       # Silver White Hair
const COLOR_BODY: Color = Color("#1a1e29")       # Dark Under-tunic
const COLOR_BLADE: Color = Color("#cbd5e1")      # Steel Weapon
const COLOR_HILTE: Color = Color("#f59e0b")      # Gold Guard
const COLOR_VOID: Color = Color("#a855f7")       # Void Glow
const COLOR_PARRY_FLASH: Color = Color("#00f5d4")# Parry Cyan Spark

func _draw() -> void:
	if not player:
		return
	
	var is_iframes: bool = player.hurtbox.is_invulnerable if player.hurtbox else false
	var alpha: float = 0.5 if is_iframes else 1.0
	
	# Draw Ghost Trail when dashing
	if player.current_state == PlayerController.State.DASH:
		draw_rect(Rect2(-8, -26, 16, 26), Color(COLOR_VOID, 0.4))
	
	# 1. Legs / Boots
	draw_rect(Rect2(-4, -8, 3, 8), Color(COLOR_BODY, alpha))
	draw_rect(Rect2(2, -8, 3, 8), Color(COLOR_BODY, alpha))
	
	# 2. Torso & Red Coat
	draw_rect(Rect2(-5, -20, 10, 13), Color(COLOR_COAT, alpha))
	# Coat Trim
	draw_rect(Rect2(-6, -17, 2, 10), Color(COLOR_COAT.darkened(0.2), alpha))
	
	# 3. Head & Silver Hair
	draw_rect(Rect2(-3, -27, 7, 7), Color("#fecdd3", alpha)) # Skin tone
	draw_rect(Rect2(-4, -30, 9, 4), Color(COLOR_HAIR, alpha)) # Hair top
	draw_rect(Rect2(-4, -28, 2, 4), Color(COLOR_HAIR, alpha)) # Hair bangs
	
	# 4. Weapon & Combat States
	match player.current_state:
		PlayerController.State.IDLE, PlayerController.State.RUN:
			# Sword sheathed on back
			draw_line(Vector2(-3, -24), Vector2(-8, -8), Color(COLOR_BLADE, alpha), 2.0)
		
		PlayerController.State.ATTACK_LIGHT_1:
			# Forward slash arc
			draw_line(Vector2(4, -16), Vector2(18, -12), COLOR_BLADE, 2.5)
			draw_arc(Vector2(6, -14), 14.0, -0.6, 0.8, 8, Color(COLOR_BLADE, 0.8), 2.0)
		
		PlayerController.State.ATTACK_LIGHT_2:
			# Heavy horizontal cleave
			draw_line(Vector2(4, -14), Vector2(22, -18), COLOR_BLADE, 3.0)
			draw_arc(Vector2(8, -16), 18.0, -1.2, 0.4, 10, Color("#ef4444", 0.9), 2.5)
		
		PlayerController.State.ATTACK_HEAVY:
			# Overhead smash
			draw_line(Vector2(2, -28), Vector2(24, -4), Color("#fbbf24", 1.0), 3.5)
		
		PlayerController.State.ABILITY:
			# Void Energy Slash
			draw_arc(Vector2(10, -16), 20.0, -1.5, 1.5, 12, COLOR_VOID, 4.0)
		
		PlayerController.State.PARRY:
			# Defensive parry stance with glowing cyan buckler aura
			var parry_col: Color = COLOR_PARRY_FLASH if player.hurtbox.is_perfect_parrying else Color("#38bdf8")
			draw_arc(Vector2(8, -15), 12.0, -1.2, 1.2, 8, parry_col, 2.5)
		
		PlayerController.State.HURT:
			# Flash white
			draw_rect(Rect2(-6, -30, 13, 30), Color(1, 1, 1, 0.7))
		
		PlayerController.State.STAGGER:
			# Dazed posture break particles
			draw_circle(Vector2(0, -32), 2.5, Color("#f59e0b"))
		
		PlayerController.State.DEAD:
			# Dissolved collapse
			draw_rect(Rect2(-8, -4, 18, 4), Color(COLOR_BODY, 0.6))
