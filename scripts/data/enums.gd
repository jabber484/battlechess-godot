class_name BattleEnums
extends RefCounted

enum Team { PLAYER, ENEMY }

enum Cover { NONE, HALF, FULL }

enum TurnPhase { IDLE, UNIT_TURN, ROUND_END, BATTLE_OVER }

enum BattleResult { NONE, VICTORY, DEFEAT }
