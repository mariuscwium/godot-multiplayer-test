extends RefCounted

func test_roundtrip() -> void:
	var pkt := Discovery.make_packet("Host One")
	T.eq(Discovery.parse_packet(pkt), "Host One", "name survives")

func test_parse_rejects_foreign_packets() -> void:
	T.eq(Discovery.parse_packet("hello"), "", "random text")
	T.eq(Discovery.parse_packet(""), "", "empty")

func test_empty_name_gets_default() -> void:
	T.eq(Discovery.parse_packet(Discovery.make_packet("")), "host", "default name")
