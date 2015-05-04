============================================
AMQP可視化ツール
============================================

--------------------------------
目的
--------------------------------

exchange/binding/queue/consumerの一連の関連付けを可視化するツールを作る。

--------------------------------
動作条件
--------------------------------

rabbitmqserverにrabbitmq_managementプラグインが導入済みのこと。

--------------------------------
仕様
--------------------------------

書式
-----

./rabbitdump 
./rabbitview channels consumers rabbitdump

説明
----

関連マップがカレントディレクトリに画像ファイルで出力される。

channels:"sudo rabbitmqctl list_channels connection pid name"
consumers:"sudo rabbitmqctl list_consumers"
rabbitdump:"rabbitdumpの出力結果"

exchange -> binding -> queue -> consumers










