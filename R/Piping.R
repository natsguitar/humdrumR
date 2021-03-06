
#### Piping humdrumR ----

#' Piping humdrumR data
#' 
#' These infix operators make it possible to use
#' the \code{\link[humdrumR:with-in-Humdrum]{with(in)Humdrum}} 
#' functions in a piping style, similar to the \code{|} (pipe)
#' in unix-style terminals, or the \code{\link[magrittr:%>%]{pipe operator}}
#' from the R package \href{https://cran.r-project.org/web/packages/magrittr/index.html}{magrittr}.
#' (In fact, the \code{\link[magrittr:%>%]{magrittr}} pipe is imported by 
#' \code{\link[humdrumR:humdrumR-package]{humdrumR}}, and we encourage you to incorporate it into
#' your `humdrumR` work flows.)
#' 
#' The key is that the function \code{\link{withinHumdrum}} always returns a new
#' \code{\linkS4class{humdrumR}} data object. Thus, you can always send the output
#' of \code{\link{withinHumdrum}} back in to a new call of \code{\link{withinHumdrum}}.
#' This is exactly what the `%hum>%` is for: on the left-hand side,
#' input a \code{\linkS4class{humdrumR}} object, on the right-hand side suitable
#' arguments to \code{\link{withinHumdrum}} (i.e., a formula, a function, or list of formulae,
#' functions, and named arguments). You can then chain this call with another call to
#' `%hum>%` and more \code{\link{withinHumdrum}} arguments.
#' 
#' `%hum<%` acts the same way as `%hum>%` except it calls \code{\link{withHumdrum}}.
#' Since \code{\link{withHumdrum}} does \emph{not} return a \code{\linkS4class{humdrumR}},
#' the output can't be piped any further (using `%hum>%` or `%hum<%`).
#' Thus, `\%hum<\%` should only be used as the last step in a pipe---you would do this
#' if you want to extract the last step in your pipe from the data's \code{\link[humdrumR:humtable]{Humdrum Table}} into
#' a normal vector or list of R data.
#' 
#' ' `\%humT\%` creates a "T" in the pipe, applying the desired expression but not keeping the result---the unaltered 
#' humdrumR input object is returned. This works simply by replacing all \code{do~} with \code{doplot~} in a call to
#' \code{\link{withinHumdrum}}. The purpose of this option, is if you want to apply expressions for their
#' \href{https://en.wikipedia.org/wiki/Side_effect_(computer_science)}{side effects},
#' for instance, for plotting.
#' 
#' `%hum[]%` is similar to `%hum>%` except it apply the formulae on its right-hand
#' side using \code{\link[humdrumR]{filterHumdrum}}. Thus, it can be used to filter/index
#' a \code{\linkS4class{humdrumR}} data object on the fly.
#' 
#' @section Plural pipes:
#' 
#' In R we often apply the same function to a `list` of data.
#' "Plural pipes" expand this idea to piping: take a `list` of data
#' and pipe each element in the list to an expression/function.
#' There are plural pipe versions of each singular pipe operator.
#' Just add an "s" to make them plural: 
#' 
#' + `%>%` (singular) : `%s>%` (plural);
#' + `%hum>%` (singular) : `%hums>%` (plural);
#' + `%hum<%` (singular) : `%hums<%` (plural);
#' + `%humT%` (singular) : `%humsT%` (plural);
#' + `%hum[]%` (singular) : `%hums[]%` (plural);
#' 
#' 
#' Note: `%s>%` is an expansion of the [magrittr::%>%] pipe operator, which
#' makes use of some clever meta-programming---we can't guarantee it will
#' always behave the way we might like!
#' @name humPipe
NULL

#' @examples
#' 
#' humdata <- readHumdrum('path*.krn')
#' 
#' humdata %hum>% ~table(.)
#' 
#' humdata %hum>%
#'      c(by~Spine, do ~ table(.)) %hum>%
#'      c(mfcol ~ c(2,2), doplot~barplot(.))
#'      
#' humdata %hum>%
#'      c(by ~ Spine, do ~ table(.)) %hum<%
#'      (do ~ sort(.))    
#' 
#' @name humPipe
#' @export
`%hum>%` <- function(humdrumR, formula) {
    doPipe(humdrumR, formula, '%hum>%', 'withinHumdrum')
}


#' @name humPipe
#' @export
`%hum<%` <- function(humdrumR, formula) {
     doPipe(humdrumR, formula, '%hum<%', 'withHumdrum')
}

#' @name humPipe
#' @export
`%humT%` <- function(humdrumR, formula) {
    if (is.list(formula)) {
        formula <- lapply(formula,
                          function(form) {
                              lhs <- rlang::f_lhs(form)
                              
                              if (is.null(lhs) || rlang::as_name(lhs) %in% c('d' , 'do')) {
                                  rlang::f_lhs(form) <- quote(dofx)
                              }
                              form
                          })
    } else {
        rlang::f_lhs(formula) <- quote(doplot)
    }
    
    invisible(doPipe(humdrumR, formula, '%humT%', 'withinHumdrum'))
}

#' @export
`%hum[]%` <- function(humdrumR, formula) {
    doPipe(humdrumR, formula, '%hum[]%', 'filterHumdrum')
}


doPipe <- function(humdrumR, formula, pipename, call) {
    # this function is used by the main piping infix operators
    # It takes a pipe splitting off multiple pipes if necessary,
    # and applies the first step in the pipe, then recalls with the rest of the pipe.
    if (class(humdrumR) != 'humdrumR') stop(call. = FALSE,
                                            glue::glue("{pipename} pipe operator can only be called with humdrumR data on left side."))
    
    if (rlang::is_formula(formula) && is.null(rlang::f_lhs(formula))) {
        splitpipe <- splitPipe(formula)
        formula <- splitpipe$Current
        rest    <- splitpipe$Rest
    } else {
        rest <- NULL
        
    }
    
    if (!is.list(formula)) formula <- list(formula)
    
    call <- as.symbol(call)
    myquo <- rlang::quo((!!call)(humdrumR, !!!formula))
    output <- rlang::eval_tidy(myquo)
    
    if (!is.null(rest)) {
        nextpipe <- call(splitpipe$Infix, quote(output), rest)
        
        eval(nextpipe)
    } else {
        output         
    }
}

splitPipe <- function(formula) {
          # this function takes a right-sided formula and splits
          # of any part of it after a %hum><% within it.
          # This is because ~blah blah %hum>% blah blah will all get captured
          expr <- rlang::f_rhs(formula)
          expr <- paste(collapse = '', deparse(expr))
          
          knownPipes <- paste(collapse = '|',
                              c('%hum<%', '%hum>%', '%humT%', '%hum\\[\\]%',
                                '%>%' ,'%T>%'))
          exprs <- strsplit(expr, split = knownPipes)[[1]]
          
          if (length(exprs) == 1) return(list(Current = formula, Rest = NULL, Infix = NA_character_))
          
          infix <- stringr::str_match(expr, knownPipes)[1] 
          
          rlang::f_rhs(formula) <- parse(text = exprs[[1]])[[1]]
          
          list(Current = formula, 
               Rest = parse(text = do.call('paste', list(collapse = ' %hum>% ', exprs[-1])))[[1]],
               Infix = infix)
          
}

splitExpression <- function(expr, on = '|') {
  # This function takes an expression and
  # and breaks it into separate expressions based on
  # top level calls to a infix function.
  if (!is.call(expr) || !deparse(expr[[1]]) %in% on) return(expr)
          
          ls <- Recall(expr[[2]], on)
          rs <- Recall(expr[[3]], on)
          c(ls, rs)
          
}



removeParentheses <- function(expr) {
 if (!is.call(expr)) return(expr)
 if (deparse(expr[[1]]) == '(') return(Recall(expr[[2]]))
          
 for (i in 2:length(expr)) {
  expr[[i]] <- Recall(expr[[i]])         
 }
 expr
}


############### Plural piping ----


#' 
#' @name humPipe
#' @export
`%s>%` <- function(lhs, rhs) {
    if (!is.list(e1)) stop(call. = FALSE,
                           'If using %s>% ("multi-pipe"), the left-side must be a list of values.')
    e2 <- rlang::enquo(e2)
    lapply(e1, function(x) eval(rlang::quo_squash(rlang::quo(x %>% !!e2))))
    
}

#' @name humPipe
#' @export
`%hums>%` <- function(list, formula) {
    lapply(list, doPipe, formula = formula, pipename = '%hums>%', call = 'withinHumdrum')
}

#' @name humPipe
#' @export
`%hums<%` <- function(list, formula) {
    lapply(list, doPipe, formula = formula, pipename = '%hums<%', call = 'withHumdrum')
}
#' @name humPipe
#' @export
`%humsT%` <- function(list, formula) {
    lapply(list, function(x) x %humT% formula)
}
#' @name humPipe
#' @export
`%hums[]%` <- function(list, formula) {
    lapply(list, doPipe, formula = formula, pipename = '%hums[]%', call = 'filterHumdrum')
}
