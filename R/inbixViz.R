# inbixViz.R - Bill White - 10/31/15
#
# Rinbix package functions for visualization.

#' Create a chord diagram from an adjacency matrix.
#' 
#' \code{adjacencyMatrixToChordDiagram} 
#' 
#' @keywords graphs
#' @family visualization functions
#' @family network functions
#' @param adj \code{matrix} adjacency matrix.
#' @param nodeLabels \code{string} vector of node labels.
#' @examples
#' data("testdata10")
#' predictors <- testdata10[, -ncol(testdata10)]
#' Acorr <- cor(predictors)
#' adjacencyMatrixToChordDiagram(Acorr)
#' @export
adjacencyMatrixToChordDiagram <- function(adj, nodeLabels = NULL) {
  if (is.null(nodeLabels)) {
    nodeLabels <- colnames(adj)
  }
  colnames(adj) <- nodeLabels
  rownames(adj) <- nodeLabels
  circlize::chordDiagramFromMatrix(adj)
}

#' Create an Igraph network from an adjacency matrix.
#' 
#' \code{adjacencyToNetList} 
#' 
#' @keywords graphs
#' @family visualization functions
#' @family network functions
#' @param Aadj \code{matrix} correlation matrix.
#' @param thresholdType \code{string} threshold type: "hard" or "soft".
#' @param thresholdValue \code{numeric} hard threshold correlation value or soft threshold power.
#' @param useAbs \code{logical} take absolute value of the correlation matrix.
#' @param useWeighted \code{logical} use weighted adjacency matrix versus binary.
#' @param verbose \code{logical} send verbose messages to standard out .
#' @param groups \code{vector} group assignments for network nodes.
#' @return \code{list} with igraph network, edge \code{list} and node list.
#' @examples
#' data("testdata10")
#' predictors <- testdata10[, -ncol(testdata10)]
#' Acorr <- cor(predictors)
#' netlist <- adjacencyToNetList(Acorr, 
#'                               thresholdType = "hard", 
#'                               thresholdValue = 0.2, 
#'                               useAbs = TRUE, 
#'                               useWeighted = TRUE)
#' @export
adjacencyToNetList <- function(Aadj = NULL, 
                               thresholdType = "hard", 
                               thresholdValue = 0.8, 
                               useAbs = TRUE, 
                               useWeighted = FALSE, 
                               verbose = FALSE,
                               groups = NULL) {
  if (is.null(Aadj)) {
    stop("adjacencyToNetList: Aadj is a required parameter")
  }
  if (verbose) cat("Begin adjacencyToNetList\n")
  Aadj <- prepareAdjacencyMatrix(Aadj, thresholdType, thresholdValue, 
                                 useAbs, useWeighted, verbose)
  nodeLabels <- colnames(Aadj)
  numNodes <- length(nodeLabels)
  # groups
  nodeGroups <- factor(seq(1, numNodes))
  if ((!is.null(groups)) && (length(groups) != numNodes)) {
    nodeGroups <- factor(groups)
  }
  numGroups <- nlevels(nodeGroups)
  if (verbose) cat("Number of node group assignment levels", numGroups, "\n")

  # create an igraph object from the edge weights matrix
  if (verbose) cat("Creating igraph object from weighted adjacency matrix\n")
  adjacencyNet <- igraph::graph_from_adjacency_matrix(Aadj, 
                                                      mode = "upper", 
                                                      weighted = TRUE, 
                                                      diag = FALSE)
  # degree is sum of connections
  nodeDegrees <- igraph::degree(adjacencyNet)
  # strength is weighted degree
  nodeStrengths <- igraph::strength(adjacencyNet)
  if (verbose) {
    print("Degrees")
    print(nodeDegrees)
    print("Weighted Degrees (Strengths)")
    print(nodeStrengths)
  }
  
  # node labels
  igraph::V(adjacencyNet)$label <- nodeLabels
  igraph::V(adjacencyNet)$shape <- "circle"

  # node colors from RColorBrewer
  nodeColors <- RColorBrewer::brewer.pal(ifelse(numGroups > 12, 12, numGroups), "Set3") 
  igraph::V(adjacencyNet)$color <- nodeColors[nodeGroups]
    
  igraph::V(adjacencyNet)$size <- nodeDegrees * 5
  igraph::V(adjacencyNet)$size2 <- igraph::V(adjacencyNet)$size

  # edge weights computed above in pairwise sums of connections
  igraph::E(adjacencyNet)$width <- igraph::E(adjacencyNet)$weight
  #E(adjacencyNet)$width <- (E(adjacencyNet)$weight / max(E(adjacencyNet)$weight)) * 7
  #E(adjacencyNet)$width <- 1

  # Offset vertex labels for smaller points (default=0).
  igraph::V(adjacencyNet)$label.dist <- ifelse(igraph::V(adjacencyNet)$size >= 5, 0, 0.2)

  # filterPercentile <- 0.95
  # filteredNetwork <- igraph::delete.edges(adjacencyNet, 
  #                                  igraph::E(adjacencyNet)[ weight < quantile(weight, filterPercentile) ])

  # build graph data structures (node and edge lists) for D3 or other network viz
  if (verbose) cat("Creating node and edge lists\n")
  # edge list
  graphLinks <- NULL
  for (i in 1:numNodes) {
    for (j in 1:numNodes) {
      if (j <= i) { next }
      if (Aadj[i, j] != 0) {
        edgeWeight <- Aadj[i, j]
        graphLinks <- rbind(graphLinks, data.frame(Source = i, Target = j, Value = edgeWeight))
      }
    }
  }
  rownames(graphLinks) <- paste("row", seq(1, nrow(graphLinks)), sep = "")
#   uniqueNodes <- unique(c(unique(graphLinks$src), unique(graphLinks$target)))
#   numUniqueNodes <- length(uniqueNodes)  
  # node list
  graphNodeLabels <- igraph::V(adjacencyNet)$label
  graphNodes <- data.frame(NodeID = 1:length(graphNodeLabels),
                           Name = graphNodeLabels, 
                           Group = as.character(nodeGroups),
                           Size = as.numeric(nodeDegrees),
                           stringsAsFactors = F)
  
  rownames(graphNodes) <- paste("row", seq(1, nrow(graphNodes)), sep = "")

  # return the Igraph object, edge list and node list
  if (verbose) cat("End adjacencyToNetList\n")
  list(net = adjacencyNet, 
       links = graphLinks, 
       nodes = graphNodes, 
       groups = as.character(nodeGroups))
}

#' Create a chord diagram from an Igraph network.
#' 
#' \code{igraphToChordDiagram} 
#' 
#' @keywords graphs
#' @family visualization functions
#' @family network functions
#' @param in.graph \code{Igraph} graph object.
#' @param nodeLabels \code{string} vector of node labels.
#' @examples
#' data("testdata10")
#' predictors <- testdata10[, -ncol(testdata10)]
#' Acorr <- cor(predictors)
#' netlist <- adjacencyToNetList(Acorr, 
#'                               thresholdType = "hard", 
#'                               thresholdValue = 0.2, 
#'                               useAbs = TRUE, 
#'                               useWeighted = TRUE)
#' igraphToChordDiagram(netlist$net, netlist$nodes$Name)
#' @export
igraphToChordDiagram <- function(in.graph, nodeLabels = NULL) {
  if (is.null(nodeLabels)) {
    nodeLabels <- igraph::V(in.graph)$label
  }
  adj <- as.matrix(igraph::get.adjacency(in.graph))
  adjacencyMatrixToChordDiagram(adj, nodeLabels)
}

#' Create a simple D3 network from a netlist created by adjacencyToNetList.
#' 
#' \code{netListToSimpleD3}
#' 
#' @keywords graphs
#' @family visualization functions
#' @family network functions
#' @param netlist \code{object} results object from adjacencyToNetList.
#' @param nodeCharge \code{numeric} charge on the nodes, negative = repulsive.
#' @examples
#' data("testdata10")
#' predictors <- testdata10[, -ncol(testdata10)]
#' Acorr <- cor(predictors)
#' netlist <- adjacencyToNetList(Acorr, 
#'                               thresholdType = "hard", 
#'                               thresholdValue = 0.2, 
#'                               useAbs = TRUE, 
#'                               useWeighted = TRUE)
#' netListToSimpleD3(netlist)
#' @export
netListToSimpleD3 <- function(netlist, nodeCharge = -2000) {
  networkD3::simpleNetwork(netlist$links, 
                           Source = "Source", 
                           Target = "Target", 
                           linkColour = "black", 
                           charge = nodeCharge)
}

#' Create a force layout D3 network from a netlist created by adjacencyToNetList.
#' 
#' \code{netListToForceD3}
#' 
#' @keywords graphs
#' @family visualization functions
#' @family network functions
#' @param netlist \code{object} results object from adjacencyToNetList.
#' @param nodeCharge \code{numeric} charge on the nodes, negative=repulsive.
#' @examples
#' data("testdata10")
#' predictors <- testdata10[, -ncol(testdata10)]
#' Acorr <- cor(predictors)
#' netlist <- adjacencyToNetList(Acorr, 
#'                               thresholdType = "hard", 
#'                               thresholdValue = 0.2, 
#'                               useAbs = TRUE, 
#'                               useWeighted = TRUE)
#' # convert nodes to zero based indexes
#' netlinks <- data.frame(Source = netlist$links$Source - 1,
#'                        Target = netlist$links$Target - 1,
#'                        Value = netlist$links$Value)
#' netnodes <- data.frame(NodeID = netlist$nodes$NodeID -1, 
#'                        Name = netlist$nodes$Name, 
#'                        Group = netlist$nodes$Group, 
#'                        Size = netlist$nodes$Size)
#' netListToForceD3(list(links = netlinks, nodes = netnodes, groups = NULL))
#' @export
netListToForceD3 <- function(netlist, nodeCharge = -2000) {
  networkD3::forceNetwork(Links = netlist$links, 
                          Nodes = netlist$nodes, 
                          Source = "Source", Target = "Target",
                          NodeID = "NodeID", Group = "Group", 
                          linkColour = "#afafaf", 
                          fontSize = 10, zoom = T, legend = T,
                          opacity = 0.9, 
                          charge = nodeCharge)
}
