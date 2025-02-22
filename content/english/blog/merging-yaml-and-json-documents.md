---
title: "Merging YAML and JSON Documents"
authors: ["Rainer Poisel"]
lastmod: 2022-11-15T10:09:08+01:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["yaml"]
categories: ["DevSecOps"]
---

This article shows how to merge documents programmatically in YAML and, or JSON formats.

<!--more-->


## Motivation and Introduction {#motivation-and-introduction}

Recently, I had to merge two Kubernetes configs in YAML format together. I did this manually. But at some point things turned out not only to be error-prone but also to be cumbersome. This brings up the following research questions:

1.  What does it take to merge two YAML files programmatically?
2.  Can this be done with JSON files as well?

I will demonstrate how to achieve this goal by merging new entries from another YAML file into an existing <span class="inline-src language-sh" data-lang="sh">`~/.kube/config`</span> (in YAML format) file.

When merging documents, one also has to make some decisions when it comes to duplicate entries in the documents. Should they be kept? Should they be appended to existing lists? Some tools offer more granular approaches on how to deal with these situations.

But before we start working with YAML and JSON files, let's have a look at some nice Shell features: here documents and process substitution. Both will help us to reduce the number of temporary files.


## Here Documents {#here-documents}

[Here Documents](https://tldp.org/LDP/abs/html/here-docs.html) are special code blocks: they use some form of I/O redirection to feed lines via `stdin` to interactive programs. Let's try this out:

```shell
cat <<EOF
one
two
  three
EOF
```

```shell
one
two
  three
```

As `cat` reads from `stdin` the contents of the here document will be written to `stdout`. Note the third line: tabs in the beginning of lines will be kept. As it is sometimes helpful, there are ways to get rid of them:

```shell
cat <<-EOF
	one two
	three four
	five six
	EOF
```

```shell
one two
three four
five six
```


## Process Substitution {#process-substitution}

Shells allow for piping `stdout` from one command to the next. What if you need to pipe the `stdout` of multiple commands? Or what if a command only accepts files as input? Process substitution to the rescue: it provides a temporary path to given commands. By reading from this path, the output of the substituted process will be provided to the reading process. Another example:

```shell
echo <(/bin/true)
```

```shell
/dev/fd/63
```

As you can see, the result of the `<()` process substitution is the path to a file which contains `stdout` of the program execution when being read. Let's now provide the `diff` command with two such temporary files:

```shell
diff -Nau <(cat <<-EOF
	{"a": "b"}
	EOF
) <(cat <<-EOF
	{"c": "d"}
	EOF
)
echo
```

```shell
--- /dev/fd/63	2022-11-15 10:09:07.641339172 +0100
+++ /dev/fd/61	2022-11-15 10:09:07.641339172 +0100
@@ -1 +1 @@
-{"a": "b"}
+{"c": "d"}

```

This is where here documents come in handy: multiple lines of input can now be provided easily to other commands. Please note that the invocation of `echo` solely serves the purpose of adding a trailing newline character to clear any buffering. Now we have all that's needed to merge YAML and JSON documents!


## Merging two JSON documents {#merging-two-json-documents}

Multiple JSON documents can be merged [easily](https://stackoverflow.com/a/24904276/203506) with the well-known [jq](https://stedolan.github.io/jq/) utility:

```shell
jq -n --argfile o1 <file1> --argfile o2 <file2>
```

Let's try it out with process substitution and here documents:

We are looking for the multiplication operator, which the [`jq` documentation](https://jqlang.github.io/jq/manual/#multiplication-division-modulo) describes as follows:

<div class="alert alert-info">

> Multiplying two objects will merge them recursively: this works like addition but if both objects contain a value for the same key, and the values are objects, the two are merged with the same strategy.
</div>

If two or more objects share the same key and if that key refers to a scalar or array, then the later objects in the input will overwrite the value (source: [StackOverflow](https://unix.stackexchange.com/a/706596)).

```shell
jq -n --argfile o1 <(cat <<-EOF
	{"a": "b"}
	EOF
) --argfile o2 <(cat <<-EOF
	{"a": "e", "c": "d"}
	EOF
) '$o1 * $o2'
```

```shell
{
  "a": "e",
  "c": "d"
}
```

The result shows how `jq` deals with duplicate keys, `a` in this case: as this key exists in both documents, the latter has precedence, i.e. the mapping of `"a": "e"` can be found in the output.

Alternatively, multiple JSON documents can be passed using the `--slurp` or the `--null-input` flags:

```shell
echo '{"a": ["b"]}' '{"a": ["e"], "c": "d"}' | jq --slurp '.[0] * .[1]'
```

```shell
{
  "a": [
    "e"
  ],
  "c": "d"
}
```

When using the `--null-input` or `-n` flag, an iterable called `inputs` will be returned. It can be processed with functions such as [reduce](https://stedolan.github.io/jq/manual/#Reduce):

```shell
echo '{"a": ["b"]}' '{"a": ["e"], "c": "d"}' | jq --null-input 'reduce inputs as $item ({}; . + $item)'
```

```shell
{
  "a": [
    "e"
  ],
  "c": "d"
}
```

Let's discuss the `reduce` cal for a bit: `reduce inputs as $item ({}; . + $item)`. Here, all input documents are provided in a variable called `inputs`. We iterate over it and assign each document to the local variable `$item`. For each `$item` we append to the root of the resulting object: `. + $item`. The empty curly braces `{}` refer to the starting object, which is empty in our case.


## Merging two YAML documents {#merging-two-yaml-documents}

Let's head over to the YAML format. Here, the [yq](https://mikefarah.gitbook.io/yq/) utility will help us to achieve what we want:

```shell
yq eval-all '. as $item ireduce ({}; . * $item)' <(cat <<EOF
---
a: [1, 2]
b: foo
EOF
) <(cat <<EOF
---
a: [3, 4]
c: bar
EOF
)
```

```shell
---
a: [3, 4]
b: foo
c: bar
```

The behavior is similar to what we have seen with `jq`. However, with `yq` one has more granular control over how values shall be merged. The `*+` operator can be used to append list values (source: [StackOverflow](https://stackoverflow.com/a/67036496)), e.g.

```shell
yq eval-all '. as $item ireduce ({}; . *+ $item)' <(cat <<EOF
---
a: [1, 2]
b: foo
EOF
) <(cat <<EOF
---
a: [3, 4]
c: bar
EOF
)
```

```shell
---
a: [1, 2, 3, 4]
b: foo
c: bar
```


## Merging Kubernetes Configs {#merging-kubernetes-configs}

Merging two Kubernetes config objects is not as straight forward as it may seem at first sight. Let's first have a look at the document structure:

```yaml
---
apiVersion: v1
clusters:
  - cluster:
      certificate-authority-data: ...
      server: https://192.168.56.10:6443
    name: kubernetes
contexts:
  - context:
      cluster: kubernetes
      user: kubernetes-admin
    name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
  - name: kubernetes-admin
    user:
      client-certificate-data: ...
      client-key-data: ...
```

These entries look quite generic. Some of these, I want to rename before merging them into my <span class="inline-src language-sh" data-lang="sh">`~/.kube/config`</span>. In addition to that, each of the three (clusters, contexts, and users) contain a list of these respective elements. As `yq` can only sum up elements of lists or replace them completely (in contrast to: element wise), we first have to remove elements that we don't want to find in the result.

First, let's rename elements in the file that should be merged into the existing <span class="inline-src language-sh" data-lang="sh">`~/.kube/config`</span>:

```shell { linenos=true, linenostart=1 }
PARTIAL_CONFIG="/tmp/admin.conf"

yq eval-all '.clusters[0].name = "k8s-cka"
		| .contexts[0].context.cluster = "k8s-cka"
		| .contexts[0].context.user = "k8s-cka-admin@k8s-cka"
		| .contexts[0].name = "k8s-cka-admin@k8s-cka"
		| .users[0].name = "k8s-cka-admin"' \
	"${PARTIAL_CONFIG}"
```

```shell

```

Nothing is written anywhere except for `stdout`. Later on, we will use this output with process substitution and write our changes inline into the Kubernetes config. Now, all elements have a telling name. As mentioned before, we have to remove entries identified by these names from the original first:

```shell { linenos=true, linenostart=1 }
ORIGINAL_CONFIG="/tmp/config" # <=== adjust this path (original Kubernetes config)

yq eval-all 'del(.clusters[] | select(.name == "k8s-cka"))
	| del(.contexts[] | select(.context.cluster == "k8s-cka"))
	| del(.users[] | select(.name == "k8s-cka-admin"))' "${ORIGINAL_CONFIG}"
```

```shell

```

Note that the [`del` operator](https://mikefarah.gitbook.io/yq/operators/delete) allows to specify a regular filter expression. Here, we combine three invocations of `del()` to get rid of the three entries we will merge in from our second file but it should also be possible to get this done in a single call go `del()`. We can now combine the two steps:

1.  Removing the existing entries
2.  Merge the new entries
    -   But before that, rename them

<!--listend-->

```shell { linenos=true, linenostart=1 }
ORIGINAL_CONFIG="/tmp/config" # <=== adjust this path (original Kubernetes config)
PARTIAL_CONFIG="/tmp/admin.conf"

# first, remove existing entries in-place
yq eval-all -i 'del(.clusters[] | select(.name == "k8s-cka"))
	| del(.contexts[] | select(.context.cluster == "k8s-cka"))
	| del(.users[] | select(.name == "k8s-cka-admin"))' "${ORIGINAL_CONFIG}"

# then, add new entries in-place, but rename them beforehand
yq eval-all -i ". as \$item ireduce ({}; . *+ \$item) | .current-context = \"k8s-cka\"" \
	"${ORIGINAL_CONFIG}" \
	<(yq eval '.clusters[0].name = "k8s-cka"
			| .contexts[0].context.cluster = "k8s-cka"
			| .contexts[0].context.user = "k8s-cka-admin@k8s-cka"
			| .contexts[0].name = "k8s-cka-admin@k8s-cka"
			| .users[0].name = "k8s-cka-admin"' \
		"${PARTIAL_CONFIG}")

# show the result
yq eval-all -P "${ORIGINAL_CONFIG}"
```

```shell

```

Et voila: we have reached our goal. Addtional configurations can now be added programmatically into our existing Kubernetes configuration. We instruct `yq` to write its changes directly into the original config by using the `-i` flag.


### Alternative approach {#alternative-approach}

Instead of merging configurations, an alternative approach would be to work with multiple Kubernetes configurations and [`direnv`](https://direnv.net/). In order to supply `kubectl` with the desired configuration, one can use the [`KUBECONFIG` environment variable](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#set-the-kubeconfig-environment-variable). Using `direnv` the value of this variable can be set when entering a given directory.

This way it is also easier to not confuse different clusters because one will only "see" one of them at a time - depending on the current working directory.


## Conclusion {#conclusion}

Merging and transforming documents such as YAML and JSON documents takes some practice. Luckily, required tools, `jq` and `yq`, are very well documented by their authors. Furthermore, loads of examples and questions can be found on StackOverflow.

With this knowledge at hand, I can enrich my personal toolbox with shortcuts to simplify my daily live as a DevSecOps engineer.
