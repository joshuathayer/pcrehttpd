package Config;

# the cluster, that the client sees

#$cluster_state = "pending-write";
$cluster_state = "normal";

$cluster = [
	{
		ip => "127.0.0.1",
		port => "8000",
	},
	{
		ip => "127.0.0.1",
		port => "8001",
	},
	{
		ip => "127.0.0.1",
		port => "8002",
	},
	{
		ip => "127.0.0.1",
		port => "8003",
	},
];	

$pending_cluster = [
	{
		ip => "127.0.0.1",
		port => "8000",
	},
	{
		ip => "127.0.0.1",
		port => "8001",
	},
	{
		ip => "127.0.0.1",
		port => "8002",
	},
	{
		ip => "127.0.0.1",
		port => "8003",
	},
	{
		ip => "127.0.0.1",
		port => "8004",
	},
];	

