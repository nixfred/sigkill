extends "res://scripts/net/rendezvous_client.gd"
## NullRendezvous (C15): the rendezvous the game uses until a relay is hosted, which waits
## on Fred's decision. It is never live, starts nothing and sends nothing: no socket, no
## address lookup, no request of any kind. A room code typed in gets NOT_LIVE; LAN join by
## address works as before.

const NOT_LIVE := "Online rooms aren't live yet. Use LAN join (address)."


func is_live() -> bool:
	return false


func requests() -> int:
	return 0
